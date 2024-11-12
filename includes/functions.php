<?php
// 获取homes目录
function getHomesDir() {
  require_once("/unas/wmi/core/wy2account.php");
  $homesDir = WY2Account::homesDir();
  return $homesDir;
}

// 获取homes下的apps目录
function getHomesAppsDir() {
  $homesDir = getHomesDir();
  // 如果没有开启homes目录，则返回空字符串
  if (trim($homesDir) == "") {
    return "";
  }
  return $homesDir . "/homes/.ext/apps";
}
?>