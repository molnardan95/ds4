# Text and Sentiment Analysis of The Most Popular songs of the last 50 years

This was a term project for the _Data Science 4: Unstructured Text Analysis_ course at the Business Analytics masters at the Central European University of Budapest. The projects aim is to identify topics, keywords and sentiments that result in the most popular songs.

__Table of contents:__

* Goal of the analysis
* About the Data
* Packages used
* Term Frequency
  * Most used terms
  * Trends
  * TF-IDF
* Sentiment analysis
* Summary
* Afterthoughts

## Goal of the analysis

The goal of my analysis was to determine what makes a song popular from a linguistic point of view.

When I originally came up with the idea, that I want to analyse lyrics, I thought it would be interesting to see difference in genres, but than I thought about how my music consumption changed over time. My favorite songs talk about very different topics nowadays than 5-10 years ago. Is it just me, who while growing up started to listen to all kinds of different music, with deeper meaning, or it's a general trend we can see over time? Do the most popular songs always talk about the same things, or do they have different topics? Do these topics change over time? Could we maybe use text analysis to come up with a song ourselves?

These are the questions that I would like to answer using the methods I acquired in class.

## About the Data

The dataset I use to answer these questions is all the lyrics from the songs that lead for at least a week the Billboard Hot 100 music toplist from 1970 to 2018. 

This information is sourced from two different websites. One of them is the [Billboard](https://www.billboard.com/charts/hot-100) website itself, from where I get the archives of the Top 100 chart going back until 1970. The other one is [Genius](https://genius.com/), source of music related news and lyrics. 

Due to the nature of these songs - one can have multiple artists, the name of the songs or artists can be challenging to interpret -, I was unable to automatically pull the lyrics for each and every song, however most of the data I needed to work with was relatively easy to get. 

Before pulling the lyrics for the songs however, I made sure to select the distinct Artist - Song combinations. This means that I'm not accounting for how long a certain song lead the toplist, only for the fact that it was there. This choice was a concious decision based on the fact that once a song gets to the top, I consider it successful enough that differentiating between a song that hold the top position for 1 and another that held it for 3 weeks doesn't help us tremendously in my goal of answering my research questions.

## Packages used

What made this analysis possible was the mostly used text analysis packages, such as the `stringr`, `tidyr`, `tidytext`, `wordcloud` and `dplyr` packages, and some other ones that are used by most of the data science projects nowadays, such as `ggplot2`, `data.table`, `tibble` and such. 

Also, the [genius](https://github.com/josiahparry/genius) package created by JosiahParry was very useful in extracting lyrics for the songs. The package had some limitations, but I was able to work with it successfully.

