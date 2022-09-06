cat << EDF >> ~/.ssh/config

Host ${hostname}
    HostName ${hostname}
    User ${user}
    IdentityFile ${identityfile}
EDF