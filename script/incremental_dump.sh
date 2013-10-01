#!/bin/bash

if [ -z "$1" ]
then
	echo usage: $0 last_known_dc1100s_measured_at
	exit 1
fi

pg_dump -U vozduh --data-only --no-owner --table=dc1100s | sed --regexp-extended "/^1\t/,/\t$1\t/ d"
