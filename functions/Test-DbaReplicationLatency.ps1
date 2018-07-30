#Development Notes
<#
    Right now I've tested this for Transactional Replication. If I wanted to do Merge Replication, would need to change
    some of the classes i'm using like TransPublication -> MergePublication

    There can be multiple publications for the same database. 
    Could make a Get-DbaReplicationPublications to help support end user to know which one to select.

    There can only be 1 distribution database for each server (IL-DTIDB-SQL can only go to WH-REPDB-SQL - distribution db, etc.)

    There could be multiple subscriptions to a publication. Write a Get-DbaReplicationSubscriptions to help support end user.
#>

#Test-DbaReplicationLatency
function Test-DbaReplicationLatency {

    Param (
        [DbaInstanceParameter[]] $SqlInstance, #Publisher
        [PSCredential]$SqlCredential,
        [DbaInstanceParameter[]] $distributor
    )

    Begin{
        Write-Host "Starting"

        # Check whether the following properties are set/assemblys exist before continuing 
        if ($null -eq [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO")) {
            Write-Host "Replication management objects not available. Please install SQL Server Management Studio."
        }
    }

    Process{

        if (Test-FunctionInterrupt) { return }

        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Connecting to $instance"

            # Step 1: Connect to the publisher
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential -MinimumVersion 9
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            # Step 2: Create an instance of TransPublication
            $transPub = New-Object Microsoft.SqlServer.Replication.TransPublication


            # Step 3: Set the Name and DatabaseName properties for the publication, and set the ConnectionContext property to the connection created in step 1.
            $transPub.Name = "tmw_live_PUB"
            $transPub.DatabaseName = "tmw_live"

            $transPub.ConnectionContext = $server.ConnectionContext.SqlConnectionObject

            

            # Step 4: Call the LoadProperties method to get the properties of the object. If this method returns false, either the publication properties in Step 3 were defined incorrectly or the publication does not exist.
            if(!$transPub.LoadProperties) {
                #Publication does not exist 
                write-host "This publication does not exist."
            }

            <#
            
            # Step 5: Call the PostTracerToken method. This method inserts a tracer token into the publication's Transaction log.
            $tracerTokenId = $transPub.PostTracerToken()

            ##################################################################################
            ### Determine Latency and validate connections for a transactional publication ###
`           ##################################################################################

            # Step 1: Connect to the distributor
            Write-Message -Level Verbose -Message "Connecting to Distributor"

            try {
                $distributorServer = Connect-SqlInstance -SqlInstance $distributor -SqlCredential $SqlCredential -MinimumVersion 9
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $distributor -Continue
            }

            # Step 2: Create an instance of the PublicationMonitor class
            $PubMon = New-Object Microsoft.SqlServer.Replication.PublicationMonitor

            $PubMon.Name = "tmw_live_PUB"
            $PubMon.DistributionDBName = "distribution" #could use the get-dbadistrubtor command here
            $PubMon.PublisherName = "IL-DTIDB-SQL"
            $PubMon.PublicationDBName = "tmw_live"

            $PubMon.ConnectionContext = $distributorServer.ConnectionContext.SqlConnectionObject;

            
            # Step 4: Call the LoadProperties method to get the properties of the object. If this method returns false, either the publication monitor properties in Step 3 were defined incorrectly or the publication does not exist.
            if(!$PubMon.LoadProperties()) {
                #Publication Monitor does not exist
                write-host "Publication does not exist :("
            }

            # Step 5: Call the EnumTracerTokens method. Cast the returned ArrayList object to an array of TracerToken objects.
            # This returns a list of tokens for the DB. Same thing as sp_helptracertokens
            $TokenList = $PubMon.EnumTracerTokens()

            
            foreach($t in $TokenList) {
                write-host $t.TracerTokenId
            }

            # Step 6: Call the EnumTracerTokenHistory method. Pass a value of TracerTokenId for a tracer token from step 5. This returns latency information for the selected tracer token as a DataSet object. If all tracer token information is returned, the connection between the Publisher and Distributor and the connection between the Distributor and the Subscriber both exist and the replication topology is functioning.
            # For this method, we are just creating one TracerToken for a single publication.
            # Is there a chance you would want to create multiple tracer tokens for the same publication?

            $TracerTokenId = $TokenList[0].TracerTokenId

            #This returns a DataSet object. I can just keep looping through this every second until all tracer token information is returned.
            $tokenInfo = $PubMon.EnumTracerTokenHistory($TracerTokenId)


            #Would to to have it setup like it is in replication monitor.
            foreach($info in $tokenInfo.Tables[0].Rows) {
                write-host "Subscriber:" $info.subscriber 
                write-host "Publisher to Distributor Latency:" $info.distributor_latency
                write-host "Subscriber DB:" $info.subscriber_db
                write-host "Distributor to Subscriber Latency:" $info.subscriber_latency
                write-host "Total Latency:" ($info.distributor_latency + $info.subscriber_latency)
            }
            #>

        }

    }

    End{
        write-host "Ending"
        # Remove the tracer tokens
    }

}