#!/bin/bash

rm hangman.db
sqlite3 hangman.db < hangman.sql

