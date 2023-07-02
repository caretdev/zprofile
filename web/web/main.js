const {
  Alert,
  Button,
  Col,
  Container,
  Form,
  InputGroup,
  Nav,
  NavItem,
  Row,
  Table,
  Modal,
  Breadcrumb,
  ListGroup,
  Navbar,
  NavDropdown,
  Tooltip,
} = ReactBootstrap

const globalState = {
  text: "foo",
};

class ModalDialog extends React.Component {
  render() {
    return (
      <Modal
        {...this.props}
        centered
      >
        <Modal.Header closeButton>
          <Modal.Title id="contained-modal-title-vcenter">
            {this.props.title}
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          {this.props.children}
        </Modal.Body>
        <Modal.Footer>
          <Button variant="outline-secondary" onClick={(e) => this.props.onReset(e)}>Reset</Button>
          <Button variant="outline-secondary" onClick={(e) => this.props.onHide(e)}>Cancel</Button>
          <Button onClick={(e) => this.props.onOK(e)}>{this.props.buttonOk}</Button>
        </Modal.Footer>
      </Modal>
    )
  }
}

class ExecutionsList extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      data: [],
    }
    this.getData();
    this.updateFilter = this.updateFilter.bind(this)
  }

  getData() {
    fetch(`api/data`)
      .then(response => response.json())
      .then((data) => {
        this.setState({ data, originalData: data })
      })
  }

  componentDidUpdate(props, state) {
    if (props.filter !== this.props.filter) {
      this.updateFilter()
    }
  }

  updateFilter() {
    let data
    if (this.props.filter) {
      const filter = this.props.filter.toLowerCase()
      data = this.state.originalData.filter((el) => {
        return Object.values(el).find(v => v && v.toLowerCase().includes(filter))
      })
    } else {
      data = this.state.originalData
    }
    this.setState({ data })
  }

  delete(id) {
    fetch(id ? `api/data/${id}` : `api/data`, { method: 'DELETE' })
      .then(response => response.json())
      .then((data) => {
        this.setState({ data, originalData: data })
      })
  }

  render() {
    return (
      <>
        <Table>
          <thead>
            <tr>
              <th>#</th>
              <th>DateTime</th>
              <th>Elapsed</th>
              <th>Command</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {this.state.data.map(row => (
              <tr style={{ cursor: 'pointer' }} onClick={() => this.props.onSelect(row.id)}>
                <td>{row.id}</td>
                <td>{row.ts}</td>
                <td>{row.totalTime}</td>
                <td><pre>{row.cmd}</pre></td>
                <td onClick={(ev) => ev.stopPropagation()}>
                  <Button variant="outline-danger" onClick={(ev) => { this.delete(row.id) }}>Delete</Button>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      </>
    )
  }
}

const showMetrics = [
  'GloRef',
  'GloSet',
  'GloKill',
  'RtnLine',
  'Time',
]

class Report extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      breadcrumb: [{ level: 0, display: '', stack: [] }],
      items: [],
      lines: [],
      routine: null,
      metrics: [],
      displayMetrics: (localStorage.getItem('showMetrics') ? localStorage.getItem('showMetrics').split(',') : showMetrics),
      columnsDialog: false,
      selectedColumns: [],
      statsMetrics: [],
      stack: this.props.stack || [],
      total: [],
      totalDisplay: [],
    };

    this.getData()
    this.getData = this.getData.bind(this)
  }

  getData() {
    let { displayMetrics, stack } = this.state
    const { onlyExecuted } = this.props
    // let stack = breadcrumb[breadcrumb.length - 1].stack
    fetch(`api/data/${this.props.id}/${stack.join('/')}`)
      .then(response => response.json())
      .then(data => {
        let { items, metrics, routines, total } = data;
        let breadcrumb = routines.map(({ name, stack }) => ({ name, stack: stack.split(',') }))
        this.props.onStackUpdate(breadcrumb)
        metrics = metrics.split(',')
        let statsMetrics = metrics.slice(4).map((el, i) => ({ min: Number.MAX_VALUE, max: -Number.MAX_VALUE, name: el }));
        let selectedMetrics = displayMetrics.map(m => metrics.indexOf(m))
        total = total.split(',')
        let totalDisplay = selectedMetrics.map(i => total[i])

        items = items.map(({ routine, label, lines, totalTime }) => {
          if (onlyExecuted) {
            lines = lines.filter(line => line.metrics.length)
          }
          lines = lines
            .map(line => ({
              ...line,
              lineNum: parseInt(line.lineNum),
              metrics: line.metrics ? (line.metrics.split(',').map(el => el.includes('.') ? parseFloat(el) : parseInt(el))) : []
            }))
          lines = lines
            .map(({ lineNum, metrics, down, code }, i) => {
              let red = 0
              if (metrics.length) {
                red = round(metrics[0] / totalTime * 100, 0)
                metrics = selectedMetrics.map(i => metrics[i])
              }

              return {
                lineNum, metrics, down, code, red
              }
            })

          return { lines, label, routine }
        })
        this.setState({ metrics, items, sorting: null, direction: null, total, totalDisplay })
      })
  }

  updateFilter() {
    let lines
    if (this.props.filter) {
      const filter = new RegExp(this.props.filter, 'i')
      lines = this.state.originalLines.filter((el) => {
        return filter.test(el.code)
      })
    } else {
      lines = this.state.originalLines
    }
    this.setState({ lines })
  }

  componentDidUpdate(props, state) {
    if (props.filter !== this.props.filter) {
      this.updateFilter()
    }
    if (props.id !== this.props.id) {
      this.getData()
    }
    if (props.stack !== this.props.stack) {
      this.setState({ stack: this.props.stack }, this.getData)
    }
    if (props.onlyExecuted !== this.props.onlyExecuted) {
      this.getData()
    }
  }

  changeSorting(column) {
    const direction = this.state.sorting === column ? !this.state.direction : true;
    let items = this.state.items;
    let empty = direction ? -Number.MAX_VALUE : Number.MAX_VALUE
    items = items.map((item) => {
      let lines = item.lines
      // lines = lines.filter((line) => line.metrics.length)
      if (column == 'lineNum') {
        lines = lines.sort(
          (a, b) => direction ? (a[column] - b[column]) : (b[column] - a[column])
        )
      } else {
        lines = lines.sort(
          (a, b) => ((a, b) => direction ? (b - a) : (a - b))(a.metrics[column] || empty, b.metrics[column] || empty)
        )
      }
      return { ...item, lines }
    })
    this.setState({ items, sorting: column, direction })
  }

  goUp() {
    let { stack } = this.state
    stack.length && stack.pop()
    stack.length && stack.pop()
    this.setState({ stack }, this.getData)
  }

  goDown(ind, lineNum) {
    let { stack } = this.state
    if (stack.length) {
      stack.push(ind + 1)
    }
    stack.push(lineNum)
    this.setState({ stack }, this.getData)
  }

  chooseColumns() {
    let selectedColumns = [...this.state.displayMetrics]
    this.setState({ selectedColumns, columnsDialog: true })
  }

  saveSelectedColumns() {
    let displayMetrics = [...this.state.selectedColumns]
    displayMetrics = displayMetrics.sort((a, b) => a.includes('Time') ? 1 : a > b ? 1 : -1)
    localStorage.setItem('showMetrics', displayMetrics.join(','))
    this.setState({ columnsDialog: false, displayMetrics }, this.getData)
  }

  resetSelectedColumns() {
    let selectedColumns = [...showMetrics]
    this.setState({ selectedColumns })
  }

  toggleColumn(col) {
    let selectedColumns = [...this.state.selectedColumns]
    if (selectedColumns.includes(col)) {
      selectedColumns.splice(selectedColumns.indexOf(col), 1)
    } else {
      selectedColumns.push(col)
    }
    this.setState({ selectedColumns })
  }

  render() {
    return (
      <>
        <Table className="lines">
          <thead className="bg-light sticky-top" style={{ zIndex: 0 }}>
            <tr>
              <th style={{ cursor: 'pointer' }} onClick={() => this.changeSorting("lineNum")}>#</th>
              {this.state.displayMetrics.map((metric, i) => (
                <th style={{ cursor: 'pointer' }} onClick={() => this.changeSorting(i)}>{metric}</th>
              ))}
            </tr>
          </thead>
          {this.state.items.map(({ lines, label, routine }, itemInd) => (
            <>
              <thead>
                <tr>
                  {this.state.stack.length
                    ? (<th style={{ cursor: 'pointer', textAlign: 'center' }} onClick={() => this.goUp()}>?</th>)
                    : (<th></th>)
                  }
                  <th colspan={this.state.displayMetrics.length}>{label}^{routine}</th>
                </tr>
              </thead >
              {
                lines.map((line) => (
                  <tbody>
                    <tr>
                      <td>{line.lineNum}</td>
                      <td colspan={this.state.displayMetrics.length}><pre>{line.code}</pre></td>
                    </tr>
                    {line.metrics.length ? (
                      <tr>
                        {line.down ? <td style={{ cursor: 'pointer', textAlign: 'center' }} onClick={() => this.goDown(itemInd, line.lineNum)}>?</td> : <td></td>}
                        {line.metrics.map((metric, i) => (
                          <td title={round(metric / this.state.totalDisplay[i] * 100, 0) + "%"} style={{
                            background: `linear-gradient(90deg, #FFE0E0 ${round(metric / this.state.totalDisplay[i] * 100, 0)}%, rgba(0,0,0,0) 0%)`
                          }}>{metric}</td>
                        ))}
                      </tr>
                    ) : <></>}
                  </tbody>
                ))
              }
            </>
          ))}
          < tfoot className="bg-light" style={{ position: 'sticky', bottom: 0 }}>
            <tr>
              <th></th>
              {this.state.totalDisplay.map((metric) => (
                <th>{metric}</th>
              ))}
            </tr>
          </tfoot>
        </Table>
        <ModalDialog
          show={this.state.columnsDialog}
          size="xl"
          aria-labelledby="contained-modal-title-vcenter"
          buttonOk={"OK"}
          title={"Select columns"}
          onHide={() => this.setState({ columnsDialog: false })}
          onOK={(_) => this.saveSelectedColumns()}
          onReset={(_) => this.resetSelectedColumns()}
        >
          {(this.state.metrics) ? (
            <Form>
              <div class="selectColumn">
                {/* {this.state.metrics.slice(0, 1).map(el => (
                  <div><Form.Check type="switch" disabled checked={this.state.selectedColumns.includes(el)} label={el} /></div>
                ))} */}
                {this.state.metrics.map((el, i) => (
                  <div><Form.Check type="switch" checked={this.state.selectedColumns.includes(el)}
                    onClick={() => this.toggleColumn(el)}
                    label={`${el} ${this.state.total.length ? `(${this.state.total[i]})` : ''}`} /></div>
                ))}
              </div>
            </Form>
          ) : <></>}
        </ModalDialog>
      </>
    )
  }
}

class Main extends React.Component {
  constructor(props) {
    super(props);
    this.mainRef = React.createRef();

    this.state = {
      id: null,
      stack: null,
      level: 0,
      breadcrumb: [],
      menu: {},
      ...this.readParams(),
      onlyExecuted: localStorage.getItem('onlyExecuted') ? localStorage.getItem('onlyExecuted') == 'true' : true,
      executions: [],
    };

    this.selectId = this.selectId.bind(this);
    this.readParams = this.readParams.bind(this);

    self = this
    window.onpopstate = () => {
      self.setState(self.readParams())
    };
  }

  componentDidUpdate(props, state) {
    if (state.onlyExecuted !== this.state.onlyExecuted) {
      localStorage.setItem('onlyExecuted', this.state.onlyExecuted)
    }
  }

  readParams() {
    const state = new Map()
    const searchParams = new URLSearchParams(document.location.search)
    searchParams.forEach((value, name) => {
      if (name == 'stack') {
        state.set(name, value.split(','))
      } else {
        state.set(name, value)
      }
    })
    return Object.fromEntries(state.entries())
  }

  selectId(id) {
    this.setState({ id, search: '', breadcrumb: [], stack: [] })
    updateParam('id', id)
    updateParam('stack', null)
  }

  renderActions() {
    const actions = []
    if (this.state.id) {
      actions.push((
        <>
          <Nav.Item><Nav.Link onClick={() => this.setState({ onlyExecuted: !this.state.onlyExecuted })}>
            <Form.Check inline type="switch" onClick={(e) => { this.setState({ onlyExecuted: e.target.checked }); e.stopPropagation() }} checked={this.state.onlyExecuted}></Form.Check>Only executed lines
          </Nav.Link></Nav.Item>
          <Nav.Item><Nav.Link onClick={() => this.mainRef.current.chooseColumns()}>Columns</Nav.Link></Nav.Item>
        </>
      ))
    }
    return actions
  }

  stackUpdate(breadcrumb) {
    this.setState({ breadcrumb, level: breadcrumb.length })
    updateParam('stack', this.state.breadcrumb.length ? this.state.breadcrumb[this.state.breadcrumb.length - 1].stack.join(',') : null)
  }

  getList() {
    fetch(`api/data`)
      .then(response => response.json())
      .then((executions) => {
        this.setState({ executions })
      })
  }

  render() {
    return (
      <>
        <Navbar bg="dark" variant="dark" expand="lg">
          <Container fluid>
            <Navbar.Collapse id="basic-navbar-nav">
              <Nav className="me-auto">
                <Nav.Item><Nav.Link onClick={() => { this.selectId(null) }}>Executions</Nav.Link></Nav.Item>
                {this.state.id &&
                  <Nav.Item>
                    <NavDropdown title={this.state.id} onClick={(ev) => this.getList()}>
                      {this.state.executions.map((el, i) => (
                        <NavDropdown.Item onClick={() => this.setState({ id: el.id })}>{el.id}</NavDropdown.Item>
                      ))}
                    </NavDropdown>
                  </Nav.Item>
                }
                {this.state.id && this.state.breadcrumb.length ? (
                  <>
                    <Nav.Item>
                      <NavDropdown title="Stack" disabled={!this.state.breadcrumb}>
                        {this.state.breadcrumb.map((el, level) => (
                          <NavDropdown.Item onClick={() => {
                            this.setState({ stack: this.state.breadcrumb[level].stack.slice(0, -2) })
                            console.log('select stack', level, this.state.breadcrumb[level].stack.slice(0, -2))
                          }}>{el.name}</NavDropdown.Item>
                        ))}
                      </NavDropdown>
                    </Nav.Item>
                    <Nav.Item><Nav.Link disabled>{this.state.breadcrumb[this.state.breadcrumb.length - 1].stack.join(',')}</Nav.Link></Nav.Item>
                  </>
                ) : (<></>)}
              </Nav>
              <Nav>
                {this.state.id ? (
                  <>
                    <Nav.Item><Nav.Link onClick={() => this.setState({ onlyExecuted: !this.state.onlyExecuted })}>
                      <Form.Check inline type="switch" onClick={(e) => { this.setState({ onlyExecuted: e.target.checked }); e.stopPropagation() }} checked={this.state.onlyExecuted}></Form.Check>Only executed lines
                    </Nav.Link></Nav.Item>
                    <Nav.Item><Nav.Link onClick={() => this.mainRef.current.chooseColumns()}>Columns</Nav.Link></Nav.Item>
                  </>) : (<>
                    <Nav.Item><Nav.Link onClick={() => this.mainRef.current.delete()}>Delete all</Nav.Link></Nav.Item>
                  </>)}
              </Nav>
            </Navbar.Collapse>
          </Container>
        </Navbar>
        <Navbar bg="light" expand="lg" style={{ zIndex: 0 }}>
          <Container fluid>
            <InputGroup>
              <Form.Control value={this.state.search} placeholder="Filter" onChange={(e) => this.setState({ search: e.target.value })}></Form.Control>
              {/* <Button>Search</Button> */}
            </InputGroup>
          </Container>

        </Navbar>
        <Container fluid>
          {this.state.id
            ? <Report
              ref={this.mainRef}
              filter={this.state.search}
              id={this.state.id}
              level={this.state.level}
              stack={this.state.stack}
              onlyExecuted={this.state.onlyExecuted}
              onStackUpdate={(breadcrumb) => this.stackUpdate(breadcrumb)}
            />
            : <ExecutionsList
              ref={this.mainRef}
              filter={this.state.search}
              onSelect={(id) => this.selectId(id)}
            />
          }
        </Container>
      </>
    )
  }
}
