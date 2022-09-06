add-content -path "C:\Users\User\.ssh\config" -value @'

Host ${hostname}
user ${user}
IdentityFile ${identityfile}
'@