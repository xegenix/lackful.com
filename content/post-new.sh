#!/bin/bash

export CONTENT_FOLDER=/srv/lackful.com/content
export DATE_PATH=$(date +%Y/%b;) # example: 2024/jan 

function create_file() {

# Start Template
local OUTPUT_BOILER="
---
date: '`date +%Y-%m-%d`'
tags: ["hugo", "blog","general"]
title: '$1'
description: ''
featured: false
image: '/img/posts/$2'
---

# $1
" # End Template 

local OUTPUT_FPATH="${CONTENT_FOLDER}/post/$DATE_PATH/$1.md"
touch $OUTPUT_FPATH

printf $OUTPUT_BOILER > $OUTPUT_FPATH

}
