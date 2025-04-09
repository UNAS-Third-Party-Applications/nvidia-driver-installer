/**
 * NvidiaDriverInstaller App
 * Defined an App to manage nvidia
 */
var NvidiaDriverInstallerApp = NvidiaDriverInstallerApp || {} //Define nvidia App namespace.
/**
 * Constructor UNAS App
 */
NvidiaDriverInstallerApp.App = function () {
  this.id = 'NvidiaDriverInstaller'
  this.name = 'NvidiaDriverInstaller'
  this.version = '6.0.2'
  this.active = false
  this.menuIcon = '/apps/nvidia-driver-installer/images/logo.png?v=6.0.2&'
  this.shortcutIcon = '/apps/nvidia-driver-installer/images/logo.png?v=6.0.2&'
  this.entryUrl = '/apps/nvidia-driver-installer/index.html?v=6.0.2&'
  var self = this
  this.NvidiaDriverInstallerAppWindow = function () {
    if (UNAS.CheckAppState('NvidiaDriverInstaller')) {
      return false
    }
    self.window = new MUI.Window({
      id: 'NvidiaDriverInstallerAppWindow',
      title: UNAS._('NvidiaDriverInstaller'),
      icon: '/apps/nvidia-driver-installer/images/logo_small.png?v=6.0.2&',
      loadMethod: 'xhr',
      width: 750,
      height: 480,
      maximizable: false,
      resizable: true,
      scrollbars: false,
      resizeLimit: { x: [200, 2000], y: [150, 1500] },
      contentURL: '/apps/nvidia-driver-installer/index.html?v=6.0.2&',
      require: { css: ['/apps/nvidia-driver-installer/css/index.css'] },
      onBeforeBuild: function () {
        UNAS.SetAppOpenedWindow(
          'NvidiaDriverInstaller',
          'NvidiaDriverInstallerAppWindow'
        )
      },
    })
  }
  this.NvidiaDriverUninstall = function () {
    UNAS.RemoveDesktopShortcut('NvidiaDriverInstaller')
    UNAS.RemoveMenu('NvidiaDriverInstaller')
    UNAS.RemoveAppFromGroups('NvidiaDriverInstaller', 'ControlPanel')
    UNAS.RemoveAppFromApps('NvidiaDriverInstaller')
  }
  new UNAS.Menu(
    'UNAS_App_Internet_Menu',
    this.name,
    this.menuIcon,
    'NvidiaDriverInstaller',
    '',
    this.NvidiaDriverInstallerAppWindow
  )
  new UNAS.RegisterToAppGroup(
    this.name,
    'ControlPanel',
    {
      Type: 'Internet',
      Location: 1,
      Icon: this.shortcutIcon,
      Url: this.entryUrl,
    },
    {}
  )
  var OnChangeLanguage = function (e) {
    UNAS.SetMenuTitle('NvidiaDriverInstaller', UNAS._('NvidiaDriverInstaller')) //translate menu
    //UNAS.SetShortcutTitle('NvidiaDriverInstaller', UNAS._('NvidiaDriverInstaller'));
    if (typeof self.window !== 'undefined') {
      UNAS.SetWindowTitle(
        'NvidiaDriverInstallerAppWindow',
        UNAS._('NvidiaDriverInstaller')
      )
    }
  }
  UNAS.LoadTranslation(
    '/apps/nvidia-driver-installer/languages/Translation?v=' + this.version,
    OnChangeLanguage
  )
  UNAS.Event.addEvent('ChangeLanguage', OnChangeLanguage)
  UNAS.CreateApp(
    this.name,
    this.shortcutIcon,
    this.NvidiaDriverInstallerAppWindow,
    this.NvidiaDriverUninstall
  )
}

new NvidiaDriverInstallerApp.App()
