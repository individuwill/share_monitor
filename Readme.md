#Share Monitor
PRTG Advanced Sensor for monitoring and measuring a SMB share's performance.
This program should be run under the context of a user who has permissions
to map the specified share. This program will output XML in the format required
by PRTG.

Put the file in  the EXEXML Advanced folder on the PRTG instance. Configure the
sensor with parameters to include all of the require parameters.
ex: `%host myshare s: coolfile.txt`

###Usage
`share-monitor hostname sharename driveletter filepath`

* hostname - fqdn or ip of host to try to map a share to
* sharename - name of CIFS/SMB share on host to map
* driveletter - drive letter to assign to mapped share. Ensure it's unique!
* filepath - path to a text file to read from. Do not include the drive letter in the path!
