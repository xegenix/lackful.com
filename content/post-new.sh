#!/bin/bash
#

function post_path() {
  export use_path=$( date +%Y/%b;)
  printf $use_path;
}

function create_file() {
post_path;
  local template_bp="
---
date: '`date +%Y-%m-%d`'
tags: ["hugo", "blog","general"]
title: '$1'
description: ''
featured: false
image: '/img/posts/$2'
---

# $1
"

local fp_output="./post/$use_path/$1.md"
touch $fp_output

printf $template_bp > $fp_output

}
