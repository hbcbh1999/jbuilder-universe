### mirage-net-fd -- MirageOS network interfaces using raw sockets

Implementation of MirageOS network interfaces using raw sockets. The
caller is in charge of opening the file-descriptor with that are passed
to the `connect` function.