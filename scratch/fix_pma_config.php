<?php
$file = 'C:/xampp/phpMyAdmin/config.inc.php';
$content = file_get_contents($file);
$tag = '?' . '>';
$content = str_replace($tag . "\r\n\$cfg['LoginCookieValidity'] = 86400;\r\n\$cfg['ExecTimeLimit'] = 300;", "\$cfg['LoginCookieValidity'] = 86400;\n\$cfg['ExecTimeLimit'] = 300;\n", $content);
$content = str_replace($tag . "\n\$cfg['LoginCookieValidity'] = 86400;\n\$cfg['ExecTimeLimit'] = 300;", "\$cfg['LoginCookieValidity'] = 86400;\n\$cfg['ExecTimeLimit'] = 300;\n", $content);
$content = preg_replace('/\\' . $tag . '\s*\$cfg\[\'LoginCookieValidity\'\]/', "\$cfg['LoginCookieValidity']", $content);
$content = preg_replace('/\\' . $tag . '\s*$/', '', $content);
file_put_contents($file, $content);
echo "SUCCESS_UPDATED\n";
