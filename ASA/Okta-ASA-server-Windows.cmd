# Project Enrollment token, to enroll the server in the associated ASA project
set enrollment_token=<replace with your enrollement token>
set canonical_name=%COMPUTERNAME%

mkdir C:\Windows\System32\config\systemprofile\AppData\Local\ScaleFT
echo CanonicalName: %canonical_name% > C:\Windows\System32\config\systemprofile\AppData\Local\ScaleFT\sftd.yaml
echo Created sftd.yaml file >> C:\sftd_bootstrap.log

echo %enrollment_token% > C:\windows\system32\config\systemprofile\AppData\Local\ScaleFT\enrollment.token
echo. >> C:\sftd_bootstrap.log
echo Added Enrollment Token to agent. >> C:\sftd_bootstrap.log

msiexec /qn -i https://dist.scaleft.com/server-tools/windows/latest/ScaleFT-Server-Tools-latest.msi >> C:\sftd_bootstrap.log 2>&1
echo. >> C:\sftd_bootstrap.log
echo Installed ASA Server Agent. >> C:\sftd_bootstrap.log
