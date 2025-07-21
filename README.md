# ParticleMusic

To make a wonderful music player for myself.

## Run
~~~bash
npm install electron@37.2.1 --save
npm install music-metadata@11.7.0
npm start
~~~

## Pack
~~~bash
npm install electron-packager --save-dev
# if target platform is window when the development enviroment is Ubuntu22.04, install wine first
sudo apt install wine
npx electron-packager . --platform=win32 --arch=x64 --out=dist/
~~~