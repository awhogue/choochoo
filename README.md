# choochoo

A Flutter app to notify you when your train is running late.

Pin the trains you regularly commute on. As the scheduled departure time approaches,
ChooChoo will watch the status of those trains on the NJ Transit DepartureVision site,
and pop a notification if the train is late or canceled.

Still very much a prototype. Currently working:

* Load static data from NJ Transit csv files.
* Fetch live data from NJ Transit DepartureVision site.

Still hacks:

* Data model for storing user's "watched" trains.
* Hard-coded Ho-Ho-Kus as the train station.

Not working at all yet:

* Timed notifications and background fetching.
* Any sort of UX for selecting your preferred trains, configuring notifications, etc.
* Any design sense at all.

#### Homescreen
<img src="https://i.imgur.com/FzEH1Sv.png" width="300px" alt="Homescreen"/>

#### Look, a notification!
<img src="https://i.imgur.com/6EZNCcp.png" width="300px" alt="Look, a notification!"/>
