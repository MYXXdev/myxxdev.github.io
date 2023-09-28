<?php
$userAgent = $_SERVER['HTTP_USER_AGENT'];

$isSafari = strpos($userAgent, 'Safari') && !strpos($userAgent, 'Chrome');
$isSamsungBrowser = strpos($userAgent, 'SamsungBrowser');
$isOperaMini = strpos($userAgent, 'Opera Mini');
$isUCBrowser = strpos($userAgent, 'UCBrowser');
$isIE = strpos($userAgent, 'Trident') || strpos($userAgent, 'MSIE');

if ($isSafari || $isSamsungBrowser || $isOperaMini || $isUCBrowser ) {
    header('Location: https://radio.kanal77.mk/safari');
} else {
    header('Location: https://radio.kanal77.mk/_index.html');
}
?>