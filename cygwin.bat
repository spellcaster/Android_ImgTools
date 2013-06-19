@echo off
:: Change this to your path to cygwin!
set path=D:\Coding\Tools\cygwin\bin

set cd=%~dp0%
set bashcd=%cd:\=/%
bash --login -i -c 'cd %bashcd%; exec bash'