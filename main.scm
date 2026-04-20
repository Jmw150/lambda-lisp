#!/usr/bin/env csi -script

(import scheme
        (chicken base)
        (chicken process-context))

(load "lib.scm")
(main (command-line-arguments))
