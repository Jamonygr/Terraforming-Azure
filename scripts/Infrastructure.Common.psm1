function Invoke-InfrastructureNative {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('az','terraform','curl.exe','pwsh','git','code')][string]$Command,[string[]]$Arguments=@(),[ValidateRange(1,120)][int]$TimeoutSeconds=30)
    # The child script receives arguments as JSON data through stdin. No shell
    # command is assembled from resource names, paths or subscription values.
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=(Get-Process -Id $PID).Path
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardInput=$true; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    foreach ($arg in @('-NoProfile','-NonInteractive','-File',(Join-Path $PSScriptRoot 'Invoke-InfrastructureCommand.ps1'))) { $start.ArgumentList.Add($arg) }
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
    try {
        $null=$process.Start()
        $process.StandardInput.WriteLine((@{command=$Command;arguments=@($Arguments)} | ConvertTo-Json -Compress))
        $process.StandardInput.Close()
        $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds*1000)) { $process.Kill($true); $process.WaitForExit(); return @{exit_code=124;output='';timed_out=$true} }
        $null=$stderr.GetAwaiter().GetResult()
        return @{exit_code=$process.ExitCode;output=$stdout.GetAwaiter().GetResult();timed_out=$false}
    } finally { $process.Dispose() }
}
Export-ModuleMember -Function Invoke-InfrastructureNative
