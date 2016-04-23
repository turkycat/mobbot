#!/bin/bash

MOBBOT_PROCESS_ID=$(ps -aux | grep mobbot | grep node | awk '{print $2}')
kill -9 $MOBBOT_PROCESS_ID
