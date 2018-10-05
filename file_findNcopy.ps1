if (Test-Path 'C:\') {
    #change the remote computer name, and give sufficent domain credentials
    $Session = New-PSSession -ComputerName "<Remote>" -Credential "<Domain>\<User>"
    Get-ChildItem C:\ -Include dor.txt -Recurse -Exclude c:\test\bin -ErrorAction SilentlyContinue | Remove-Item
    #first path is the source second part is the destination
    Copy-Item "c:\folder\file.txt" -Destination "c:\test\bin\" -Force -ToSession $Session
            }
if (Test-Path 'D:\') {
    Get-ChildItem D:\ -Include dor.txt -Recurse -ErrorAction SilentlyContinue | Remove-Item
            }
if (Test-Path 'E:\') {
    Get-ChildItem E:\ -Include dor.txt -Recurse -ErrorAction SilentlyContinue | Remove-Item
            }
