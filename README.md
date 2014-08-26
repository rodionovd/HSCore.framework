HSCore.framework
================

HoneySound Core framework.  


## Integration    

##### Installation
* Download the source archive for either `master` or `develop` branch, unpack into your project directory;  

**OR**

* Use git submodules:  

  ```
$ cd /your/project/dir/
$ git submodule add https://github.com/rodionovd/HSCore.framework.git
...
$ cd HSCore.framework
$ git submodule update --init --recursive
$ git checkout [master|develop]
  ```

##### Setting up 

 1.  Drag'n'drop `HSCore.xcodeproj` into your project source tree;  
 2.  Add `HSCore.framework` to «Link Binary with Libraries» build phase of your application; 
 3.  Add a target dependency on `HSCore.framework` for your application;  
 4.  Add «Copy File» build phase: copy `HSCore.frameowork` to destination «Frameworks»;  
 5.  Change Codesigning Identity of the **entire `HSCore.framework` subproject** to your own codesign identity (the same  one that you use for the main application);  
 6.  Open your application's `Info.plist` and add the following key to the dictionary there:  

  ```xml
  <key>SMPrivilegedExecutables</key>
  <dict>
    <key>me.rodionovd.RDInjectionWizard.injector</key>
    <string>certificate leaf[subject.CN]</string>
  </dict>
  ``` 

## Cleaning up  

Sometimes you'll need to reset the `RDInjectionWizard`'s privileged helper (*I encourage you to do that every time you pull a new revision of `HSCore`*). Do achive that do the following:  

```bash
$ cd /your/project/dir/
$ cd ./HSCore.framework/RDInjectionWizard
$ ./unload_deamon.sh
```
(you'll be prompted for a password).  
