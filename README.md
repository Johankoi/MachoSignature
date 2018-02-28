### 使用说明
![resign-tool.png](http://upload-images.jianshu.io/upload_images/7079027-fefbb797a49ce89d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如上图所示，可以选择要签名的包文件，这个工具支持ipa，app，xcarchive三种文件作为签名源文件，重签名之后都会生成ipa。  
Provisioning Profile：用于选择描述文件，会像xcode一样索所有双击安装在电脑上的描述文件，列举出来，会自动过滤掉过期的。  
Signing Certificate: 选择对应的证书，同样会检索系统钥匙串安装的可用的证书，会自动过滤掉过期的。  
new BundleID: 可以重新指定一个新的BundleID。  
App Display Name: 可以重新设定一个app名字。  
App Version: 可以重新指定version。  
App Short Version: 可以重新指定Short version。

### 安装方法
1.直接下载源码使用xcode运行  
2.从[GitHub仓库releases](https://github.com/HanProjectCoder/ResignForiOS/releases)找最新发布的dmg安装包，下载安装即可

### 命令行模式：
支持使用命令行调起签名功能：(前提是要通过dmg安装到应用目录下)
命令：  
```
open -a ResignForiOS --args 
```
必加参数： 
-i  要重签名的ipa/app/xcarchive文件路径  
-p 描述文件路径  
-c 证书名字，可以在终端使用security find-identity -v -p codesigning命令列出所有在钥匙串的证书，可以挑选出所需签名的证书名字  
-o  输出ipa路径  
使用举例：
```
open -a ResignForiOS  --args  -i /xxx/xxx.ipa  -p /xxx/xxx.mobileprovision -c "xxx: xx."  -o /xxx/xxx.ipa 
```
**注意使用此命令行模式，执行命令之前，要关闭退出之前打开的窗口。**


### 签名失败可能的问题以及解决方案
##### 1.目标机有多个版本xcode，命令行环境下没有select对应的当前的xcode版本：
检查一下当前命令号环境下的xcode：
```
xcode-select --print-path
```
如果发现指定版本不是当前所用xocde，就使用以下命令指定xcode
```
sudo xcode-select -switch /Applications/XcodeXXX.app/Contents/Developer 
```
##### 2.缺少Apple Worldwide Developer Relations Certification Authority证书
检查一下是否安装了AppleWWDRCA.cer：
```
security find-certificate -c "Apple Worldwide Developer Relations Certification Authority"
```
如果提示找不到，就打开 [苹果官方证书下载地址](http://developer.apple.com/certificationauthority/AppleWWDRCA.cer) 点击下载后,双击cer文件即可。OK。
**ps：事实上如果缺少AppleWWDRCA.cer，所有申请的开发者证书，在钥匙串里面的显示都会变成不信任证书。**
