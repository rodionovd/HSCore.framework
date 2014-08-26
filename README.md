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
1. Drag'n'drop `HSCore.xcodeproj` into your project source tree;  
2. Add `HSCore.framework` to «Link Binary with Libraries» build phase of your application; 
3. Add a target dependency on `HSCore.framework` for your application;  
4. Add «Copy File» build phase: copy `HSCore.frameowork` to destination «Frameworks»;  
5. Change Codesigning Identity of the **entire `HSCore.framework` subproject** to your own codesign identity (the same one that you use for the main application);  
