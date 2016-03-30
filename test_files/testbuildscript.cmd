@echo off
call coffee -c dbgbot.coffee
call coffee -c ../scripts/builds.coffee
call coffee -c ../scripts/dbmanager.coffee
node ../scripts/builds.js
@echo on