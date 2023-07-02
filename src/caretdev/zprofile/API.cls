Class caretdev.zprofile.API Extends %CSP.REST
{

Parameter CONTENTTYPE = {..#CONTENTTYPEJSON};

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>

<Route Url="/data" Method="GET" Call="GetList" />
<Route Url="/data" Method="DELETE" Call="Delete" />
<Route Url="/data/:id" Method="DELETE" Call="Delete" />
<Route Url="/data/:id" Method="GET" Call="GetData" />
<Route Url="/data/:id/" Method="GET" Call="GetData" />
<Route Url="/data/:id/(\d+(?:/\d+)*)" Method="GET" Call="GetData" />
<Route Url="/data/:id" Method="POST" Call="GetData" />

</Routes>
}

ClassMethod outputStatus(pSC As %Status) As %Status
{
  Set result = {
    "status": "OK"
  }
  If ($$$ISERR(pSC)) {
    Do $System.Status.DecomposeStatus(pSC, .errors)
    If $Data(errors(1)) {
      Set code = errors(1, "code")
      Set error = $Piece(errors(1), "#" _ code _": ", 2, *)
      Set result.code = code
      Set result.status = error
    }
  }
  Do result.%ToJSON()
  Return $$$OK
}

ClassMethod ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status
{
  Set %response.Status = pHttpStatus
  Set %response.ContentType = ..#CONTENTTYPEJSON

  If $$$ISERR(pSC) {
    Do ..outputStatus(pSC)
  }
  Else {
    Set result = {
      "status": (pHttpStatus)
    }
    Do result.%ToJSON()
  }

  Return $$$OK
}

ClassMethod GetList() As %Status
{
  Set rgn = ##class(caretdev.zprofile.main).#ReportGN
  Set result = []
  Set id = ""
  For {
    Set id = $Order(@rgn@(id), -1, info)
    Quit:id=""
    Set $ListBuild(pid, ts, cmd) = info
    Set ts = $ZDatetime(ts, 3, 1)
    Set totalTime = $Piece($Get(@rgn@(id, 0)), ",")
    Do result.%Push({
      "id": (id),
      "pid": (pid),
      "ts": (ts),
      "cmd": (cmd),
      "totalTime": (totalTime)
    })
  }
  Set stream = ##class(%Stream.GlobalCharacter).%New()
  Do result.%ToJSON(.stream)
  Do stream.OutputToDevice()
  Quit $$$OK
}

ClassMethod Delete(id = "")
{
  Set rgn = ##class(caretdev.zprofile.main).#ReportGN
  If id'="" {
    Set rgn = $Name(@rgn@(id))
  }
  Kill @rgn
  Quit ..GetList()
}

ClassMethod GetData(id = "", stack = "") As %Status
{
  Set result = {}
  Set stack = $ListFromString(stack, "/")

  If id'="" {
    Set rgn = ##class(caretdev.zprofile.main).#ReportGN
    Set rgn = $Name(@rgn@(id))
    Set dgn = rgn
    Set metrics = $Get(@dgn@("metrics"))
    Set dgn = $Name(@dgn@(0, 1))
    Set ptr = 0
    Set tStack = ""
    Set routines = []
    Set place = @dgn@(-1)
    While $ListNext(stack, ptr, ind) {
      Quit:'$Data(@dgn@(ind))
      Set dgn = $Name(@dgn@(ind))
      Set tStack = tStack _ $ListBuild(ind)
      If '$Data(@dgn@(-1), place),place'="" {
        Set place = $Piece(place, "^") _ "+" _ ind _ "^" _ $Piece(place, "^", 2)
        Do routines.%Push({"name": (place), "stack": ($ListToString(tStack))})
      }
    }

    Set items = []
    If $Data(@dgn@(-1)) {
      Do items.%Push(..GetStackChunk(dgn))
    } Else {
      Set ind = ""
      For {
        Set ind = $Order(@dgn@(ind))
        Quit:ind=""
        Do items.%Push(..GetStackChunk($Name(@dgn@(ind))))
      }
    }
    Set total = @rgn@(0)
    Set result = {
      "metrics": (metrics),
      "items": (items),
      "routines": (routines),
      "total": (total)
    }
  }

  Set stream = ##class(%Stream.GlobalCharacter).%New()
  Do result.%ToJSON(.stream)
  Do stream.OutputToDevice()
  Quit $$$OK
}

ClassMethod GetStackChunk(dgn)
{
  Set routine = $Get(@dgn@(-1))
  Set label = $Piece(routine, "^")
  Set routine = $Piece(routine, "^", 2)
  Set result = {
    "routine": (routine),
    "label": (label),
    "lines": []
  }
  Set lineNum = 0
  Set firstMetrics = ""
  Set lineNumEnd = $Order(@dgn@(100000000), -1)
  For lineNum=0:1:lineNumEnd {
    Set code = $Text(@label+lineNum^@routine)
    If '$Data(@dgn@(lineNum), metrics) {
      Quit:(code="")&&($Order(@dgn@(lineNum))="")
      Do result.lines.%Push({"lineNum": (lineNum), "code": (code), "metrics": ""})
      Continue
    }
    Set lineObj = {
      "lineNum": (lineNum),
      "code": (code)
    }
    If $Data(@dgn@(lineNum)) > 1 {
      Do lineObj.%Set("down", 1, "boolean")
    }
    Set:(firstMetrics="") firstMetrics = metrics
    Set time = $Piece(metrics, ",", 1)
    Do $Increment(totalTime, time)
    Set lineObj.metrics = metrics
    Set ngn = $Query(@dgn@(lineNum + 1))
    If ngn'="" {
      If $QSubscript(ngn, $QLength(ngn))="-1" {
        Set ngn = $Query(@ngn)
      }
      Set nextMetrics = $Get(@ngn)
      #; Set result.startTime = +$Piece(firstMetrics, ",", 3)
      #; Set result.endTime = +$Piece(nextMetrics, ",", 3)
    }
    Set result.totalTime = totalTime
    Do result.lines.%Push(lineObj)
  }
  Return result
}

}
