Import-Module BizagiAutomationSdk
Import-Module BizagiCISdk
Import-Module BizagiUtil
Import-Module InstallBizagi
Update-BPM -channel CURRENT
Install-Bizagi -componentName BPM -channel QA -physicalPath C:\Bizagi\Enterprise\Projects -environmentName RNF
exit 0
