#!/usr/bin/env iriscli

Set $Namespace = "%SYS"

zpm "install passwords-tool"

Set user("Password") = ##class(caretdev.Passwords).Generate(20)
Set sc = ##class(Security.Users).Modify("_system", .user)
Do:'sc $system.OBJ.DisplayError(sc)
Set sc = ##class(Security.Users).Modify("admin", .user)
Do:'sc $system.OBJ.DisplayError(sc)

Set web("AutheEnabled") = 64
Do ##class(Security.Applications).Modify("/zprofile/api", .web)

Set resource("PublicPermission")="R"
Do ##class(Security.Resources).Modify("%DB_FHIRSERVER", .resource)

Set $Namespace = "FHIRSERVER"
Do $system.OBJ.Load("~/zprofile/.github/workflows/demo.xml.gz")
