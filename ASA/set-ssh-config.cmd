@echo off

echo # To use ScaleFT proxycommand, add this configuration block to your $HOME/.ssh/config  >> %USERPROFILE%\.ssh\config
echo Match exec "%USERPROFILE%\AppData\Local\Apps\ScaleFT\bin\sft.exe resolve -q  %%h" >> %USERPROFILE%\.ssh\config
echo     ProxyCommand %USERPROFILE%\AppData\Local\Apps\ScaleFT\bin\sft.exe proxycommand  %%h >> %USERPROFILE%\.ssh\config
echo     UserKnownHostsFile %USERPROFILE%\AppData\Local\ScaleFT\proxycommand_known_hosts >> %USERPROFILE%\.ssh\config

