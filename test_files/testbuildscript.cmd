@echo off
call coffee -c dbgbot.coffee
call coffee -c ../scripts/builds.coffee
node ../scripts/builds.js
@echo on