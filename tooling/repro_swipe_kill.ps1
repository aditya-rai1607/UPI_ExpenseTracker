param(
    [string]$Emulator = "emulator-5554",
    [string]$PackageName = "com.example.upi_expense_tracker",
    [switch]$Execute,
    [int]$WaitBeforeKillSeconds = 3,
    [int]$WaitAfterSmsSeconds = 3,
    [string]$SmsNumber = "12345",
    [string]$SmsMessage = "INR 1,500.00 debited from A/c XXXX5678 by PHONEPE UPI on 13-Jun-2026",
    [string]$OutputDir = "tooling\repro_outputs"
)

function Invoke-AdbShell {
    param($args)
    $cmd = @('adb','-s',$Emulator,'shell') + $args
    if ($Execute) {
        Write-Host "EXEC: $($cmd -join ' ')"
        & adb -s $Emulator shell $args
    } else {
        Write-Host "DRY: $($cmd -join ' ')"
    }
}

function Invoke-Adb {
    param($args)
    $cmd = @('adb','-s',$Emulator) + $args
    if ($Execute) {
        Write-Host "EXEC: $($cmd -join ' ')"
        & adb -s $Emulator @args
    } else {
        Write-Host "DRY: $($cmd -join ' ')"
    }
}

# Prepare output path
if ($Execute) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
} else {
    Write-Host "DRY: create directory $OutputDir"
}

# 1. Clear logcat
Invoke-AdbShell @('logcat','-c')

# 2. Launch app (foreground)
Invoke-AdbShell @('monkey','-p',$PackageName,'-c','android.intent.category.LAUNCHER','1')
Start-Sleep -Seconds 2

# 3. Background app (HOME)
Invoke-AdbShell @('input','keyevent','KEYCODE_HOME')
Start-Sleep -Seconds 1

# 4. Wait then kill process
Write-Host "Waiting $WaitBeforeKillSeconds seconds before kill..."
Start-Sleep -Seconds $WaitBeforeKillSeconds

# Try pidof then kill -9, fallback to am kill
$pidCmd = "pidof $PackageName"
if ($Execute) {
    $pid = & adb -s $Emulator shell $pidCmd 2>$null | ForEach-Object { $_.Trim() }
    if ($pid) {
        Write-Host "Killing pid $pid"
        & adb -s $Emulator shell "kill -9 $pid"
    } else {
        Write-Host "pidof returned empty; using am kill"
        & adb -s $Emulator shell "am kill $PackageName"
    }
} else {
    Write-Host "DRY: adb -s $Emulator shell $pidCmd; then kill -9 <pid> or am kill $PackageName"
}

Start-Sleep -Seconds 1

# 5. Send SMS while app is killed
Write-Host "Sending SMS to emulator ($SmsNumber): $SmsMessage"
Invoke-Adb @('emu','sms','send',$SmsNumber,$SmsMessage)

# 6. Wait for the native receiver to process
Write-Host "Waiting $WaitAfterSmsSeconds seconds for native processing..."
Start-Sleep -Seconds $WaitAfterSmsSeconds

# 7. Fetch shared_prefs before cold-launch
$prefsFileHost = Join-Path $OutputDir "prefs_before_launch.xml"
$runAsCmd = "run-as $PackageName cat /data/data/$PackageName/shared_prefs/upi_tracker_native_prefs.xml"
if ($Execute) {
    Write-Host "Saving prefs (before launch) to $prefsFileHost"
    & adb -s $Emulator shell $runAsCmd > $prefsFileHost 2>$null
} else {
    Write-Host "DRY: adb -s $Emulator shell $runAsCmd > $prefsFileHost"
}

# 8. Cold-launch app
Write-Host "Cold-launching app (bring to foreground)"
Invoke-AdbShell @('monkey','-p',$PackageName,'-c','android.intent.category.LAUNCHER','1')
Start-Sleep -Seconds 3

# 9. Fetch shared_prefs after cold-launch
$prefsFileHost2 = Join-Path $OutputDir "prefs_after_launch.xml"
if ($Execute) {
    Write-Host "Saving prefs (after launch) to $prefsFileHost2"
    & adb -s $Emulator shell $runAsCmd > $prefsFileHost2 2>$null
} else {
    Write-Host "DRY: adb -s $Emulator shell $runAsCmd > $prefsFileHost2"
}

# 10. Capture recent logcat (filtered) to file
$logFile = Join-Path $OutputDir "logcat_recent.txt"
$filter = 'NativeTransactionProcessor|NativeSmsBridge|I/flutter'
if ($Execute) {
    Write-Host "Capturing logcat to $logFile (filter: $filter)"
    & adb -s $Emulator logcat -d | Select-String -Pattern $filter | Out-File -FilePath $logFile -Encoding utf8
} else {
    Write-Host "DRY: adb -s $Emulator logcat -d | Select-String -Pattern $filter > $logFile"
}

Write-Host "Repro script finished. OutputDir: $OutputDir"
if (-not $Execute) {
    Write-Host "Note: script ran in DRY-RUN mode. Re-run with -Execute to perform actions." 
}
