/*
Copyright (C) 2013-2016 Micah Losli <micah.losli@gmail.com>

This file is part of Panpipe.

Panpipe is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Panpipe is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Panpipe.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.4
import "pandora.js" as Pandora
import "Song.js" as Song

import "../AudioStream.js" as AudioStream

Item {
    /* Signals */
    signal loginFailed()
    signal loginSucceeded()
    signal stationsLoaded()

    /* public properties */
    property bool connected
    property var userStationsAlphabetical
    property var userStationsByDate
    property bool stationSelected
    property string currentStationId
    property string currentStationName
    property string currentStationToken
    property var playlistData
    property int playlistCurrentIndex
    property var stationSearchResults

    property var stationDetails

    property string audioStreamString

    //property alias userResponseString: Pandora.userResponse

    /* Initialization operations */
    Component.onCompleted: {
        stationSelected = false;
        //currentStationToken = null;
        playlistData = []; /* Define playlistData as an array */
    }

    /* Login */
    function login(username, password, callback) {

        function loginAttempt(username, password) {
            //_lastAttemptedUsername = username;
            if (username && password) {
                Pandora.connect(username, password, loginResponse);

                playlistCurrentIndex = 0;
                playlistData = []; /* Define playlistData as an array */

            } else {
                loginFailed();
            }
        }

        function loginResponse(data) {
            if (data.stat == "ok") {
                console.log("Login succeeded!");
                connected = true;
                loginSucceeded();
                if (callback) {
                    callback(data);
                }
            } else {
                console.log("Login failed :/");
                loginFailed(_lastAttemptedUsername);
                connected = false;
            }
        }

        loginAttempt(username, password);
    }

    /* Logout */
    function logout() {
        connected = false;
        currentStationId = "";
    }

    /* Retrieve stations */
    function retrieveStations(callback) {

        function retrieveStationsAttempt() {
            Pandora.getUserStations(retrieveStationsResponse);
        }

        function retrieveStationsResponse(pandoraResponse) {
            userStationsByDate = pandoraResponse.result;
            if (pandoraResponse.stat === "ok") {
                console.log("stations received");
                stationsLoaded();
            } else {
                console.log("station request failed");
            }

            if (callback) {
                callback(pandoraResponse)
            }
        }

        retrieveStationsAttempt();
    }

    /* Send feedback */
    function giveFeedback(favorable, trackToken, callback) {

        function giveFeedbackAttempt() {
            /* Send the feedback to Pandora */
            Pandora.sendFeedback(favorable, trackToken, receiveFeedbackResponse);
        }

        function receiveFeedbackResponse(pandoraResponse) {
            if (pandoraResponse.stat === "ok") {

            } else {
                console.log("feedback failed");
            }

            if (callback) {
                callback(pandoraResponse);
            }
        }

        giveFeedbackAttempt();
    }

    /*
        Public functions
    */

    function setStation(stationToken) {
        /* Indicate that a station has been selected */
        stationSelected = true;

        currentStationToken = stationToken;

        retrievePlaylist(currentStationToken);
    }

    function loadNextSong() {
        /* Update location in the playlist */
        playlistCurrentIndex = playlistCurrentIndex + 1;
        console.log("advancing to the next song!");

        /* Retrieve more songs for playlist if necessary */
        if (playlistCurrentIndex >= (playlistData.length - 1)) {
            retrievePlaylist(currentStationToken);
        }
    }

    function searchForMusic(query) {
        Pandora.searchMusic(query, searchForMusicResponse);
    }

    function updateQuickMix(stationIds) {
        Pandora.setQuickMix(stationIds, updateQuickMixResponse);
    }

    function newUserStation(musicToken) {
        Pandora.newStation(musicToken, newUserStationResponse)
    }

    function deleteUserStation(stationToken) {
        Pandora.deleteStation(stationToken, deleteUserStationResponse);
    }

    function getUserStation(stationToken) {
        console.log("Getting details for " + stationToken);
        Pandora.getStation(stationToken, getUserStationResponse);
    }

    function deleteUserFeedback(feedbackId) {
        Pandora.deleteFeedback(feedbackId, deleteUserFeedbackResponse);
    }

    function addMusicSeed(musicToken, stationToken) {
        Pandora.addSeed(musicToken, stationToken, null);
    }

    function removeMusicSeed(seedId) {
        Pandora.deleteSeed(seedId, deleteSeedResponse);
    }

    /*
        Private functions
    */
    function retrievePlaylist(stationToken) {
        console.log("retrieving more songs!");
        Pandora.getStationPlaylist(stationToken, retrievePlaylistResponse);
    }

    //alternate version with specified callback function
    function retrieveMoreSongs(stationToken, callback) {
        console.log("retrieving more songs!");
        Pandora.getStationPlaylist(stationToken, callback);
    }

    /*
        Callback functions
    */

    function retrievePlaylistResponse(playlistResult) {
        var tempPlaylistArray = [];
        var playlistStationId;
        var playlist = playlistResult.result.items;

        for (var i = 0; i < playlist.length; i++) {
            /* Make sure this item is a song and not an ad */
            if (playlist[i].artistName) {
                var aSong = new Song.Song(playlist[i]);

                tempPlaylistArray.push(aSong);

                playlistStationId = playlist[i].stationId;
            }
        }

        if (playlistStationId == currentStationId) {
            /* If retrieving playlist for current station, add to master playlist */
            playlistData = playlistData.concat(tempPlaylistArray);
        } else {
            /* If a new station is selected, start rebuilding the master playlist */
            playlistData = tempPlaylistArray;
            playlistCurrentIndex = 0;
            currentStationId = playlistStationId;
        }
    }

    function searchForMusicResponse(searchResult) {
        /* experimental: insert match field identifier */
        for(var i = 0; i < searchResult.songs.length; i++) {
            searchResult.songs[i].matchType = "Songs"
        }

        for(var i = 0; i < searchResult.artists.length; i++) {
            searchResult.artists[i].matchType = "Artists"
        }

        stationSearchResults = searchResult.songs;
        stationSearchResults = stationSearchResults.concat(searchResult.artists);
    }

    function updateQuickMixResponse(statusCode) {
        console.log("update QuickMix status code: " + statusCode);

        if(statusCode === "ok") {
            retrieveStations();
        }
    }

    function newUserStationResponse(result) {
        console.log("New station result: " + result);

        retrieveStations();
    }

    function deleteUserStationResponse(statusCode) {
        console.log("Delete user station status code: " + statusCode);

        if(statusCode === "ok") {
            retrieveStations();
        }
    }

    function getUserStationResponse(stationData) {
        console.log("Station details received.");
        stationDetails = stationData;

        console.log("details url: " + stationDetails.stationDetailUrl);
    }

    function deleteUserFeedbackResponse(statusCode) {
        console.log("Delete user feedback status code: " + statusCode);
    }

    function deleteSeedResponse(statusCode) {
        console.log("Delete seed status code: " + statusCode);
    }

    /*
        Helper functions
    */

    /* A string comparison function used to sort stations by station name */
    function __strcmp ( str1, str2 ) {
        // http://kevin.vanzonneveld.net
        // +   original by: Waldo Malqui Silva
        // +      input by: Steve Hilder
        // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
        // +    revised by: gorthaur
        // *     example 1: strcmp( 'waldo', 'owald' );
        // *     returns 1: 1
        // *     example 2: strcmp( 'owald', 'waldo' );
        // *     returns 2: -1

        return ( ( str1 == str2 ) ? 0 : ( ( str1 > str2 ) ? 1 : -1 ) );
    }

    /* A comparison function used to sort stations by creation date */
    function __pandoraDateCompare(a, b) {
        var date_a = new Date(a.year, a.month, a.day, a.hours, a.minutes, a.seconds);
        var date_b = new Date(b.year, b.month, b.day, b.hours, b.minutes, b.seconds);

        return date_b.getTime() - date_a.getTime();
    }

    /* Function to place the "QuickMix" station back at the top of the station list */
    function __moveQuickMix(stationList) {
        var temp;
        for(var i = 0; i < stationList.length; i++) {
            if(stationList[i].stationName == "QuickMix") {
                temp = stationList[i];

                //now shift other items down
                for(var j = i; j > 0; j--) {
                    stationList[j] = stationList[(j - 1)];
                }

                stationList[0] = temp;
                break;
            }
        }
    }

    /* Function to sort the stations list alphabetically */
    function __sortStationArrayAlphabetically(stationsList) {
        stationsList.sort(function(a,b){return __strcmp(a.stationName, b.stationName)});
        __moveQuickMix(stationsList);
    }

    /* A function to identify the index of the station in the list, given a stationToken */
    function __findStationIndexFromToken(stationToken, stationList) {
        for(var i = 0; i < stationList.length; i++) {
            if( stationToken === stationList[i].stationToken ) {
                return i;
            }
        }

        //If token not found, return negative one
        return -1;
    }

}
