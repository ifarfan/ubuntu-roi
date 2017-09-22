<?php
#
$opt[1] = "--vertical-label \"Hosts\" ";
#
$def[1] =   rrd::def("count", $RRDFILE[1], $DS[1], "AVERAGE");

$def[1] .= rrd::line3("count", "#000000", "Host Check Count") ;

?>
