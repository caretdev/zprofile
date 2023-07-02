Class caretdev.zprofile.main
{

Parameter ReportGN = "^caretdev.zprofile.report";

ClassMethod Trace(cmd = "", monitor = 1)
{
#def1arg send(%msg) Do $System.Event.Signal($ZChild, $lb(%msg))
  Set ts = $ZHorolog
  Try {
    Set $Ecode = ""
    Quit:cmd=""
    Set src(0) = 1
    Set src(1) = " " _ cmd
    Set res = $Compile(src,0,errs)
    If res {
      Set p = 0
      While $ListNext(errs, p, err) {
        Set $ListBuild(line, offset, ernum, text) = err
        Write !,text
      }
      Return
    }
    Job ..Listen()
    Set child = $ZChild
    Quit:child=""
    Set $ListBuild(res, rgn) = $System.Event.WaitMsg("",1)
    #; throw:$System.Event.Wait("",1)'=1 ##class(%Exception.General).%New("test")
    #; quit
    Write !,"Started listener in background: ", child, !

    Set device = $System.Device.GetNullDevice()
    $$$send("Cmd", cmd)
    #; set monitor = 0
    If monitor {
      Set metrics = ##class(%Monitor.Process).Metrics()
      $$$send("Metrics", "Time," _ metrics)
      Do ##class(%Monitor.Process).Enable()
      Set metrics = ##class(%Monitor.Process).Clear()
    }
    Else {
      $$$send("Metrics", "Time")
    }
    Set %zpzh = $ZHorolog, %st = $Estack
    Set %dir = 0, %place = "@"

    Set loggingCmd = ""
    Set loggingCmd = loggingCmd _ " Set %metrics = $ZUtil(84,7,6), %zptzh = $ZHorolog"
    Set loggingCmd = loggingCmd _ " If $System.Event.Wait("""",.1)'=1 { break ""OFF"" write !,""Something went wrong, listener died"",! }"
    Set loggingCmd = loggingCmd _ " Do $System.Event.Signal($ZChild, $ListBuild(""Trace"", %place, %dir, ($Get(%zptzh) - $Get(%zpzh)), %metrics))"
    Set loggingCmd = loggingCmd _ " Set %zpzh = %zptzh, %dir = $Estack - %st, %st = $Estack, %place = $Stack($Stack - 2, ""PLACE"")"
    Set loggingCmd = loggingCmd _ " Do $ZUtil(84,2,6)"
    Set executeCode = "(""" _ $Replace(loggingCmd, """", """""") _  """)"
    ZBreak $:"T"::executeCode
    $$$send("StartTS", $ZTimestamp)
    $$$send("Start", $ZHorolog)
    Try {
      Do $ZUtil(84,2,6)
      Break "L+" Xecute cmd Break "OFF"
      Xecute loggingCmd
    } Catch ex {
      Write !,"ERROR: ", ex.DisplayString(),!
      #; $$$send("Error", ex.DisplayError())
    }
    Write !,"Elapsed: ", $ZHorolog-ts
    Set ts = $ZHorolog
  } Catch ex {
    Write !,"ERROR: ", ex.DisplayString(),!
  }
  $$$send("End", $ZTimestamp)
  Break "OFF"
  Do ##class(%Monitor.Process).Disable()

  If $Data(child) {
    For {
      Quit:'$Data(^$Job(child))
      Quit:'$System.Event.Count(child)
      Hang 0.1
    }
  }
  Write !,"Done: ", $ZHorolog-ts
  Quit
}

ClassMethod Start()
{

  Set ind = ""
}

ClassMethod Listen()
{
#define pop(%l) $List(%l),%l=$List(%l,2,*)
  #; Wait time for the executed line
  Set timeout = 60

  Set rgn = $Name(@..#ReportGN)
  Try {
    Set ind = $Order(@rgn@(""), -1) + 1
    Set rgn = $Name(@rgn@(ind))
    Do $System.Event.Signal($ZParent, rgn)
    Set @rgn = $ListBuild($ZParent)
    Set dgn = rgn

    Set started = 0
    Set metricsNames = ""
    Set stack = ""
    Set lastLine = 0

    For {
      Do $System.Event.Signal($ZParent, "")
      Set $ListBuild(res, msg) = $System.Event.WaitMsg("", timeout)
      If res<=0 {
        Set @rgn@(0) = res
        Quit
      }
      #; Set @rgn@("_", $Increment(@rgn@("_"))) = msg
      #; Continue
      Quit:msg=""
      Set type = $$$pop(msg)
      Continue:type=""
      Quit:type="End"
      If type = "Metrics" {
        Set metrics = $$$pop(msg)
        Set metricsNames = $ListFromString(metrics, ",")
        Set @rgn@("metrics") = metrics
      }
      ElseIf type = "Cmd" {
        Set cmd = $$$pop(msg)
        Set $List(@rgn, 3) = cmd
      }
      ElseIf type = "StartTS" {
        Set startTS = $$$pop(msg)
        Set $List(@rgn, 2) = startTS
      }
      ElseIf type = "Start" {
        Set lzh = $$$pop(msg)
        Set started = 1
      }
      Continue:'started
      Continue:type'="Trace"
      Set place = $$$pop(msg)
      Set place = $Piece(place, " ")
      Continue:place["@"
      Set direction = $$$pop(msg)
      Set time = $$$pop(msg)
      Set metrics = $$$pop(msg)
      #; GloRef
      Set $Piece(metrics, ",", 1) = $Piece(metrics, ",", 1) - 1
      Set metrics = time _ "," _ metrics

      Set label = $Piece($Piece(place, "^"), "+")
      Set line = + $Piece($Piece(place, "^"), "+", 2)
      Set routine = $Piece(place, "^", 2)
      Set name = label _ "^" _ routine

      If direction>0 {
        Break:direction>1
        For tIndex=1:1 {
          Quit:'$Data(@dgn@(lastLine,tIndex))
          Quit:($Get(@dgn@(lastLine,tIndex, -1))=name)
        }
        Set stack = stack _ $ListBuild($ListBuild(lastLine, tIndex, name))
        Set dgn = $Name(@dgn@(lastLine, tIndex))
        Set @dgn@(-1) = name
        Set stackPlace = $ListLength(stack)
      }
      ElseIf direction<0 {
        Set stack = $List(stack, 1, * + direction)
        Set tdgn = rgn
        For i = 1:1:$ListLength(stack) {
          Set $ListBuild(tLine, tIndex, tName) = $List(stack, i)
          Set tdgn = $Name(@tdgn@(tLine, tIndex))
          Break:@tdgn@(-1)'=tName
        }
        Set dgn = tdgn
      }
      Else {
        #; Another call on the same level (e.g %Close at Quit, or on top on the same line)
        If name'=@dgn@(-1) {
          Set tdgn = rgn
          Set tCur = $List(stack, *)
          Set tLastLine = $List(tCur)
          Set stack = $List(stack, 1, * -1)
          For i = 1:1:$ListLength(stack) {
            Set $ListBuild(tLine, tIndex, tName) = $List(stack, i)
            Set tdgn = $Name(@tdgn@(tLine, tIndex))
            Break:@tdgn@(-1)'=tName
          }
          For tIndex=1:1 {
            Quit:'$Data(@tdgn@(tLastLine,tIndex))
            Quit:($Get(@tdgn@(tLastLine,tIndex, -1))=name)
          }
          Set tdgn = $Name(@tdgn@(tLastLine, tIndex))
          Set stack = stack _ $ListBuild($ListBuild(tLastLine, tIndex, name))
          Set dgn = tdgn
          Set @dgn@(-1) = name
        }
      }
      Set lastLine = line
      If $Data(@dgn@(line), prevMetrics) {
        For i=1:1:$Length(metrics, ",") {
          Set $Piece(metrics, ",", i) = $Piece(metrics, ",", i) + $Piece(prevMetrics, ",", i)
        }
      }
      Set @dgn@(line) = metrics
    }
    Set @rgn@(0) = ..CountTotal(dgn)
  }
  Catch ex {
    Set @rgn@(-1) = ex.DisplayString() _ "; " _ $Get(dgn)
  }
}

ClassMethod CountTotal(dgn)
{
  Set metricsCnt = 0
  Set metricsTotal = ""
  Set lineNum = -1
  Quit:'$Data(@dgn@(-1)) ""
  For {
    Set lineNum = $Order(@dgn@(lineNum), 1, metrics)
    Quit:lineNum=""
    Set:'metricsCnt metricsCnt = $Length(metrics, ",")
    Set up = $Piece(metrics, ",", 4)
    Set ind = ""
    For {
      Set ind = $Order(@dgn@(lineNum, ind))
      Quit:ind=""
      Set metricsUp = ..CountTotal($Name(@dgn@(lineNum, ind)))
      For i=1:1:metricsCnt {
        Set $Piece(metrics, ",", i) = $Piece(metrics, ",", i) + $Piece(metricsUp, ",", i)
      }
    }
    Set @dgn@(lineNum) = metrics
    For i=1:1:metricsCnt {
      Set $Piece(metricsTotal, ",", i) = $Piece(metricsTotal, ",", i) + $Piece(metrics, ",", i)
    }
  }
  Quit metricsTotal
}

}
