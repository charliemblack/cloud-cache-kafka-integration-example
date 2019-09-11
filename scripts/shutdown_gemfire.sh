#!/usr/bin/env bash


gfsh << ENDGFSH
connect
member
1234567
shutdown --include-locators=true --time-out=30
Y
ENDGFSH
