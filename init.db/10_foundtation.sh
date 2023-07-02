#!/usr/bin/env iriscli

set namespace = "FHIRSERVER"
zn "HSLIB"
Do ##class(HS.HC.Util.Installer).InstallFoundation(namespace)
