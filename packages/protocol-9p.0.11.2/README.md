## OCaml-9P -- An implementation of the 9p protocol in pure OCaml

[![Build Status](https://travis-ci.org/mirage/ocaml-9p.png?branch=master)](https://travis-ci.org/mirage/ocaml-9p) [![Coverage Status](https://coveralls.io/repos/mirage/ocaml-9p/badge.png?branch=master)](https://coveralls.io/r/mirage/ocaml-9p?branch=master)

ocaml-9p is an implementation of the 9P protocol, written in
a Mirage-friendly style.

Please read the [API documentation](https://mirage.github.io/ocaml-9p).

Example of the CLI example program:
```
o9p ls --username vagrant   /var
drwxr-xr-x ? root root 4096 Feb 2  2015 lib
drwxr-xr-x ? root root 4096 Mar 15 2015 cache
-rwxrwxrwx ? root root 9    May 10 2014 lock
drwxrwxrwx ? root root 4096 Jul 6  2015 tmp
drwxr-xr-x ? root root 4096 May 11 2014 spool
drwxrwxr-x ? root sshd 4096 Sep 28 2015 log
drwxr-xr-x ? root root 4096 Sep 21 2015 backups
drwxrwxr-x ? root mail 4096 Apr 16 2014 mail
drwxr-xr-x ? root root 4096 Apr 16 2014 opt
drwxrwxr-x ? root 50   4096 Apr 10 2014 local
-rwxrwxrwx ? root root 4    May 10 2014 run
```

This library supports the [9P2000.u extension](http://ericvh.github.io/9p-rfc/rfc9p2000.u.html)
