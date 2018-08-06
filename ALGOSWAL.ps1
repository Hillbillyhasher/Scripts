<#
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT 
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------

Date ........... August 2nd, 2018
Script ......... AlgoSwapp
Language ....... PowerShell
Author ......... HillBillyHasher

Description: This script will check the difficulty of a preferred coin and swap to that coin if the difficulty 
is low enough.  If the difficulty is too high, it switches to an alternate coin.  Run this as a scheduled 
task and it will swap automatically.


-----------------------------------------------------------------------
#>

cls

<#
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
You must change these varialbes to match your rig setup.
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
#>

$diff_max              = 20000                                            # When the difficulty of the Preferred_Coin is lower than this value, 
                                                                          #   your preferred coin will be selected to mine.

$Preferred_Coin        ='RVN'                                             # Preferred Coin to Mine - batch file must be named RVN.BAT as an example.

$Alt_Coin              ='zencash'                                         # This is the alternate coin that will mine if the difficulty is too high.

$uri                   = "https://www.whattomine.com/coins/234.json"      # The URL of the REST-API on WHATTOMINE.COM  To get this URL go to 
                                                                          #    https://www.whattomine.com, click "Coins" at the top, search for and
                                                                          #    click on your coin.  At the top right there is a "JSON" button, click
                                                                          #    that.  The link this produces is what you put here.   

$BaseDir               = "C:\BBTMiner\"                                   # Your Miner Directory - where your individual coin batch files are

$LogDir                = "C:\Scripts\Logs\"                               # Where you want the log file to be written.

$Start_Batch_File_Name = "C:\BBTMiner\StartMiner.bat"                     # Full path and name of the batch file that starts your miner on reboot

<#
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-----------------------------------------------------------------------
#>


$Start_Batch_File      = Get-Content -Path $Start_Batch_File_Name  
$Coin_Batch_File       = ""
$MinerParameters       = @()
$Perform_Reboot        = $False

$Date = Get-Date
$CharDate = $Date.Month.ToString("00")+'/'+$Date.Day.ToString("00")+'/'+$Date.Year.ToString("0000")+' '+$Date.Hour.ToString("00")+":"+$Date.Minute.ToString("00")+":"+$Date.Second.ToString("00")
$LogFileName = $LogDir+"CheckMiner_Log_Day_"+$Date.Day+".txt"

<#
------------------------------------
Get the current difficulty of Raven from WhatToMine.com
------------------------------------
#>

$result = Invoke-Webrequest -uri $uri 
if (!$result) {Exit}
$Data = $Result.Content | ConvertFrom-JSon
$Difficulty = $Data.difficulty

<#
------------------------------------
Read the Batch File that starts your miner which needs to be formatted 
as below.  We are looking for the "call zencash.bat" line and will 
extract the name of the coin from the batch file name.  

**** NOTE ****: Batch file names must match Preferred_Coin and Alt_Coin defined above.
                Only one value will be available and the rest will be "REMed" out as comments.

----------------

@Echo Off
Echo About to start Miner
cd C:\BBTMiner
Timeout 60

rem call Rvn.bat
call zencash.bat
rem call ZCash.BAT
rem call ETH.BAT
rem call ZCoin.bat
rem call vertcoin.bat
rem call GoByte.bat
rem call SmartCash.bat
------------------------------------
#>

ForEach($line in $Start_Batch_File) {
    $p = $line.Split()
    if ($p[0].ToLower() -ne "call") {Continue}
    if ($p[1].Length -lt 5) {Continue}
    if (!$p[1].ToLower().EndsWith("bat")) {Continue}
    $Coin_Batch_File_Location = $BaseDir + $p[1]
    $CoinName = ($p[1].Split('.'))[0].ToUpper()
    Break
}

if ($Coin_Batch_File_Location -eq "" ) {
    Write-Host
    Write-Host "Unable to find Coin Specific Batch File Being Called in $Start_Batch_File_Name"
    Write-Host
    Exit
}

Write-host 
Write-Host "Coin Batch File .... $Coin_Batch_File_Location" -ForegroundColor Yellow
Write-Host

<#
------------------------------------
Read the coin batch file which should be formmated something like the 
following.  The script parses the "SET" commands to get pertinent 
information but mostly what is needed is the name of the miner EXE file.
You need this to Kill the task before you can start a new algo miner 
batch file.

----------------

@echo off
cls
:Start
setlocal EnableDelayedExpansion 

Rem
Rem OC Settings: Power: 53, Core:120, Memory +500
Rem 

Set Coin_Acronym=zen
SET ZENCASH_WALLET_ADDRESS=<YOUR WALLET ADDRESS GOES HERE>
SET MINER_WEBLOGIN=--+--
SET WORKER_PASSWORD=--+--
SET MINER_NAME=MinerName
SET EMAIL_ADDRESS=youremail@gmail.com

setx GPU_FORCE_64BIT_PTR 0 >nul 2>&1
setx GPU_MAX_HEAP_SIZE 100 >nul 2>&1
setx GPU_USE_SYNC_OBJECTS 1 >nul 2>&1
setx GPU_MAX_ALLOC_PERCENT 100 >nul 2>&1
setx GPU_SINGLE_ALLOC_PERCENT 100 >nul 2>&1

CD C:\BBTMINER

ECHO ZenCash DTSM Miner on LuckPool.Net Hub
Miners\DTSM_zm_0.6_win\zm.exe -server na.luckpool.net -user %ZENCASH_WALLET_ADDRESS%.%MINER_NAME% -pass x -port 3057
------------------------------------
#>

$Coin_Batch_File = Get-Content -Path $Coin_Batch_File_Location

$MinerName = ""
$MinerEXE = ""
$MinerLocation = ""

ForEach($line in $Coin_Batch_File) {
    $p = $line.Trim().Split()
    
    if ($p[0] -eq "rem" -or $p[0].Length -lt 1) {Continue}
    
    if ($p[0] -eq 'set') {
        if ($p[1].Length -lt 10) {Continue}
        if ($p[1].SubString(0,10).ToLower() -eq 'miner_name') {
            $MinerName = ($line.Trim().Split('='))[1].Trim()
            Continue
        }
        
        if ($p[1] -like "*=*") {
            $parm = $p[1].Split("=")
            $object = '' | Select Name,Data
            $object.Name = $parm[0].Trim().ToLower()
            $object.Data = $parm[1].Trim()
            $MinerParameters += $object
        }
    }

    if ($p[0].Length -lt 4) {Continue}

    if ($p[0].SubString($p[0].Length -4 , 4).ToLower() -eq '.exe') {
        $MinerLocation = $BaseDir+$p[0]
        $MinerEXE = (Get-ChildItem -Path $MinerLocation).BaseName.ToLower()
        Break
    }
}

if ($MinerName -eq '' -or $MinerEXE -eq ''  -or $MinerLocation -eq '') {
    Write-Host
    Write-Host "Cannott find Miner Name, EXE or Location:" -FORE Red
    Write-Host "MinerName .......... $MinerName" -FORE Red
    Write-Host "MinerEXE ........... $MinerEXE" -FORE Red
    Write-Host "MinerLocation ...... $MinerLocation" -FORE Red
    Write-Host
}

Write-Host "MinerName .......... $MinerName" -FORE Yellow
Write-Host "MinerEXE ........... $MinerEXE" -FORE Yellow
Write-Host "MinerLocation ...... $MinerLocation" -FORE Yellow
Write-Host


<#
------------------------------------
Here we are getting the name of the batch file which should be the name 
of the coin. RVN.Bat, ZenCash.Bat, ZCoin.Bat
------------------------------------
#>

$Coin_Name = (Get-ChildItem -Path $Coin_Batch_File_Location).BaseName
$HashRate = 0

<#
------------------------------------
This next section is checking to insure that the preferred coin is being
mined based on the difficulty of RVN.

It also creates a new miner Start batch file (collects it in $StartArray)
in case the algorithm needs to change.
------------------------------------
#>

$StartArray = @()

$PreferredBat = $Alt_Coin.ToLower() + '.bat'
$NewCoin = $Alt_Coin

if ($Difficulty -lt $diff_max) {
    $PreferredBat = $Preferred_Coin.ToLower() + '.bat' 
    $NewCoin = $Preferred_Coin
}

ForEach($line in $Start_Batch_File) {
    if ($line) {
        $p=$line.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)

        if ($p[0].ToLower() -eq "call" -and $line.Trim().ToLower().EndsWith('.bat')) {
            if ($p[1].ToLower() -eq $PreferredBat) {
                Write-Host 'No Change' -ForegroundColor Green   # We're mining the preferred coin, get out.
                Write-Host
                $msg = $Chardate +' - AlgoSwap - Check '+$CoinName+' Difficulty('+$Difficulty.ToString()+') - Difficulty Too High, No Change'
                $Result = Add-Content -Path $LogFileName -Value $msg -ErrorAction SilentlyContinue
                Exit
            }
            $StartArray += 'rem ' + $line
            continue
        }
        if ($p[1].ToLower() -eq "call" -and $line.Trim().ToLower().EndsWith('.bat')) {
            if ($p[2].ToLower() -eq $PreferredBat) {        
                $StartArray += 'call ' + $PreferredBat
                continue
            }
        }

        $StartArray += $line
    }
    Else {$StartArray += ''}
}

<#
------------------------------------
Algorithm swap will take place:

Print the new batch file on the screen.
------------------------------------
#>

foreach($item in $StartArray) {
    Write-Host $item -ForegroundColor Green
}

<#
------------------------------------
Kill the current mining process and log it.
------------------------------------
#>

for ($i = 1; $i -lt 10; $i++) {
    Write-Host
    Write-Host "Check for Running Mining Processes" -fore Cyan
    $processes = Get-Process -Name $MinerEXE -ErrorAction SilentlyContinue
    if (!$processes) {Break}
    Write-Host
    Write-Host "Stopping process" $MinerEXE -ForegroundColor Red
    Stop-Process -Name $MinerEXE -Force -Verbose
    $msg = $Chardate +' - Change in Mined Algorithm Due to Raven Difficulty ('+$Difficulty.ToString()+') - Mining '+ $NewCoin
    $Result = Add-Content -Path $LogFileName -Value $msg -ErrorAction SilentlyContinue
    Write-Host "Wait 10 seconds...." -ForegroundColor Cyan
    sleep -Seconds 10
}


<#
------------------------------------
Write the new mining batch file with the correct algorithm
------------------------------------
#>

$StartArray | Set-Content -Path $Start_Batch_File_Name

<#
------------------------------------
Reboot if we need to.
------------------------------------
#>

if ($i -eq 10) {          
    Write-Host
    Write-host "Going to reboot in 15 seconds....." -fore Red
    Sleep -seconds 15
    Restart-Computer -Force
    Exit
}

<#
------------------------------------
Start the new Preferred Coin Batch file
------------------------------------
#>

Start-Process -FilePath $Start_Batch_File_Name -Verbose
