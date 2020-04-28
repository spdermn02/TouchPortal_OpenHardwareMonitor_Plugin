#!C:\Strawberry\bin\perl

use Win32::Exe;
$exe = Win32::Exe->new($ARGV[0]);
$exe->set_single_group_icon($ARGV[1]);
$exe->write;
