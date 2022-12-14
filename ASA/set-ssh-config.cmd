:: This script creates a properly formated .ssh/config file to facilitate
:: native SSH command use of sft.exe for authentication to ASA protected servers.
:: No warranty expressed or implied, use at your own risk.

:: suppress console output
@echo off

:: create the .ssh directory if it does not exist.
mkdir "%USERPROFILE%\.ssh" 2> nul

:: write Match stanza to .ssh/config
echo # This Match stanza allows SSH to leverage sft.exe for server name resolution and authentication.  >> "%USERPROFILE%\.ssh\config"
echo Match exec "%USERPROFILE%\AppData\Local\Apps\ScaleFT\bin\sft.exe resolve -q  %%h" >> "%USERPROFILE%\.ssh\config"
echo     ProxyCommand %USERPROFILE%\AppData\Local\Apps\ScaleFT\bin\sft.exe proxycommand  %%h >> "%USERPROFILE%\.ssh\config"
echo     UserKnownHostsFile %USERPROFILE%\AppData\Local\ScaleFT\proxycommand_known_hosts >> "%USERPROFILE%\.ssh\config"

