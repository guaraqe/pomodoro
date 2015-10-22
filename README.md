# pomodoro

This is a simple command line utility for the Pomodoro Method, written in Haskell. It was made for personal use and learning.

You can use it by:

    pomodoro configFile tag1,tag2,tag3 "description"
    
An example config file is:

    database-file: /home/guaraqe/.pomodoro/database
    notification-title: Pomodoro
    notification-text: Time's Up!
    notification-sound: /home/juan/.pomodoro/bell.mp3
    duration: 1500

It depends on `inotify` and `play`.
