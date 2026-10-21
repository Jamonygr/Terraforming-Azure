#requires -Version 7.2
# Internal bounded-process adapter. Its parent explicitly selects local/Azure mode.
$ErrorActionPreference='Stop'
$request=[Console]::In.ReadLine() | ConvertFrom-Json
if ($request.command -notin @('az','terraform','curl.exe','pwsh','git','code')) { throw 'Unsupported command.' }
$nativeArgs=@($request.arguments)
& $request.command @nativeArgs
exit $LASTEXITCODE
