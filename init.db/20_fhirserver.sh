#!/usr/bin/env iriscli

    Set $namespace = "FHIRSERVER"
    
    Set appKey = "/fhir/r4"
    Set strategyClass = "HS.FHIRServer.Storage.Json.InteractionsStrategy"
    set metadataPackages = $lb("hl7.fhir.r4.core@4.0.1")

    // Install elements that are required for a FHIR-enabled namespace
    Do ##class(HS.FHIRServer.Installer).InstallNamespace()

    // Install an instance of a FHIR Service into the current namespace
    Do ##class(HS.FHIRServer.Installer).InstallInstance(appKey, strategyClass, metadataPackages)

    // Configure FHIR Service instance to accept unauthenticated requests
    set strategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(appKey)
    set config = strategy.GetServiceConfigData()
    set config.DebugMode = 4
    do strategy.SaveServiceConfigData(config)