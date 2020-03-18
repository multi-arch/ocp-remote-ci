#!/bin/bash
semanage port -a -t http_port_t -p tcp 8080
semanage port -a -t http_port_t -p tcp 8443
