add-content -path "C:\Users\Jack Shepherd\.ssh\config" -value @'

Host ${hostname}
user ${user}
IdentityFile ${identityfile}
'@