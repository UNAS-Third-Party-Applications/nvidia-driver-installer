<?php
include 'functions.php';
// 获取请求参数
$jsonData = file_get_contents("php://input");
// 解析JSON数据
$jsonObj = json_decode($jsonData);
// 现在可以使用$jsonObj访问传递的JSON数据中的属性或方法
// 获取token，通过token获取用户名
$token = $jsonObj->token;
if(empty($token)) {
  echo json_encode(array(
    'err' => 1,
    'msg' => 'Token is empty'
  ));
  return;
}
session_id($token);
// 强制禁止浏览器的隐式cookie中的sessionId
$_COOKIE = [ 'PHPSESSID' => '' ];
session_start([ // php7
    'cookie_lifetime' => 2000000000,
    'read_and_close'  => false,
]);
// 获取用户名
$userId = isset($_SESSION['uid']) && is_string($_SESSION['uid']) ? $_SESSION['uid'] : $_SESSION['username'];
if(!isset($userId)) {
  echo json_encode(array(
    'err' => 1,
    'msg' => 'User information not obtained'
  ));
  return;
}
// 获取要进行的操作
$action = $jsonObj->action;

if($action == "getInfo") {
  // 获取homes目录中管理应用的配置的目录
  $hmoesExtAppsFolder = getHomesAppsDir();
  if($hmoesExtAppsFolder == "") {
    // homes目录未开启，提醒用户开启homes目录
    echo json_encode(array(
      'err' => 1,
      'msg' => 'Please enable the home directory in the User Account before use'
    ));
    return;
  }
  // 获取版本信息
  // modinfo nvidia | grep ^version: | sed 's/^version:\s*//'
  exec("modinfo nvidia | grep ^version: | sed 's/^version:\s*//'", $output, $returnVar);
  if($returnVar == 0 && sizeof($output) > 0) {
    $version = $output[0];
  } else {
    $version = "";
  }
  // 读取配置目录中是否有安装信息
  $installInfo = $hmoesExtAppsFolder.'/nvidia/info.json';
  if(file_exists($installInfo)) {
    $jsonString = file_get_contents($installInfo);
    // 如果想要以数组形式解码JSON，可以传递第二个参数为true
    $manageConfigData = json_decode($jsonString, true);
    $manageConfigData['version'] = $version;
    if($manageConfigData['progress'] == "100%" || array_key_exists('error', $manageConfigData)) {
     exec("sudo rm -f $installInfo");
    }
    echo json_encode($manageConfigData);
  } else {
    echo json_encode(array(
      'version' => $version
    ));
  }
} if($action == "install") {
  // 保存配置并启动或者停止服务
  // 获取homes目录中管理应用的配置的目录
  $hmoesExtAppsFolder = getHomesAppsDir();
  if($hmoesExtAppsFolder == "") {
    // homes目录未开启，提醒用户开启homes目录
    echo json_encode(array(
      'err' => 1,
      'msg' => 'Please enable the home directory in the User Account before use'
    ));
    return;
  }

  // 获取要安装的驱动版本
  if (property_exists($jsonObj, 'version')) {
    $version = $jsonObj->version;
  } else {
    // 要安装的驱动版本未设置
    echo json_encode(array(
      'err' => 1,
      'msg' => 'Please select the driver version to install'
    ));
    return;
  }

  $tmpDir = $hmoesExtAppsFolder.'/nvidia';
  // 判断安装临时缓存目录是否存在
  if (is_dir($tmpDir)) {
    // 修改安装临时缓存目录权限和所有者
    exec("sudo chown www-data:www-data $tmpDir");
    // 实测必须给www-data rwx权限（也就是7），否则使用file_put_contents写入配置文件无法写入
    exec("sudo chmod 755 $tmpDir");
  } else {
    // 文件夹不存在，创建文件夹
    exec("sudo mkdir -p $tmpDir");
    // 修改安装临时缓存目录权限和所有者
    exec("sudo chown www-data:www-data $tmpDir");
    // 实测必须给www-data rwx权限（也就是7），否则使用file_put_contents写入配置文件无法写入
    exec("sudo chmod 755 $tmpDir");
    if (!is_dir($tmpDir)) {
      // 安装临时缓存目录创建失败
      echo json_encode(array(
        'err' => 1,
        'msg' => 'Failed to create temporary directory'
      ));
      return;
    }
  }

  // nvidia驱动安装脚本所在目录
  $sbinPath = "/unas/apps/nvidia-driver-installer/sbin";
  // 修改安装脚本的权限和所有者
  $installScript = $sbinPath."/install.sh";
  exec("sudo chown www-data:www-data $installScript");
  exec("sudo chmod 755 $installScript");

  $lockFile = $tmpDir.'/file.lock';
  exec("sudo touch $lockFile");
  exec("sudo chmod 777 $lockFile");
  // 执行nvidia的安装命令
  $fp = fopen($lockFile, 'w+');
  if (flock($fp, LOCK_EX)) {
    // 加锁成功
    // 进行并发处理
    $installInfo = $tmpDir."/info.json";
    if(file_exists($installInfo)) {
      echo json_encode(array(
        'err' => 1,
        'msg' => 'The driver is currently being installed, please do not repeat the operation.'
      ));
    } else {
      exec("sudo touch $installInfo");
      exec("sudo chmod 777 $installInfo");
      file_put_contents($installInfo, json_encode(array(
        "installVersion" => $version,
        'progress' => '0%'
      )));
      // 使用exec()函数异步执行nvidia的安装脚本
      exec("setsid nohup sudo $installScript $tmpDir $version > ".escapeshellarg($tmpDir."/install.log")." 2>&1 &");
      echo json_encode(array(
        'err' => 0
      ));
    }
    flock($fp, LOCK_UN); // 释放锁
  } else {
      // 加锁失败
      echo json_encode(array(
        'err' => 1,
        'msg' => 'The driver is currently being installed, please do not repeat the operation.'
      ));
  }
  fclose($fp);
}
?>