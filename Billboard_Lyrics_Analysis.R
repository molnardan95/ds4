### Data Pull and Cleaning

rm(list = ls())

library(rvest)
library(dplyr)
library(tibble)
library(genius)
library(stringr)
library(tidytext)
library(tidyr)
library(wordcloud)
library(ggplot2)
library(reshape2)
library(tm)
library(topicmodels)
library(data.table)




# Initial empty tibble for songs on the list
toplist <- tibble()

# Scrape the top list leaders from the Billboard site
# The site contains this info in tabular format

for (i in 1970:2018) {
  url <- paste("https://www.billboard.com/archive/charts/", i, "/hot-100", sep = "")
  
  yearly_toplist <- url %>% 
    read_html() %>% 
    html_nodes(xpath = '/html/body/main/article/div/div/div/table') %>%
    html_table()
  
  yearly_toplist <- yearly_toplist[[1]]%>%
    mutate(year = i)
  
  toplist <- bind_rows(toplist, yearly_toplist)
  
  Sys.sleep(sample(seq(2, 5, by=0.001), 1))
}

# Some data cleaning is required to use the genius package
# Even though I did some data cleaning, due to the nature of the data,
# It is hard to download every song's lyrics automatically

# This method below will load more than 80% of songs from this period

clean_toplist <- toplist %>%
  mutate(Title = str_remove_all(Title, "[',().&]")) %>%
  mutate(Artist = str_trim(word(Artist, 1, sep = "Feat"))) %>%
  mutate(Artist = str_trim(word(Artist, 1, sep = ","))) %>%
  mutate(Artist = str_trim(word(Artist, 1, sep = "\\+"))) %>%
  mutate(Artist = str_trim(word(Artist, 1, sep = "&"))) %>%
  mutate(Artist = str_trim(word(Artist, 1, sep = "And"))) %>%
  mutate(Artist = str_remove_all(Artist, "['+.]"))

clean_lyrics <- clean_toplist %>%
  select(Title, Artist) %>%
  distinct() %>%
  add_genius(Artist, Title, type = "lyrics")

# Save the lyrics into a csv so I don't need to run this again
write.csv(clean_lyrics, file = "Billboard_1970_2018_Lyrics.csv")


##########################################################################################
###                              End of Data pull and cleaning                         ###
##########################################################################################

### Analysis
lyrics <- read.csv("Billboard_1970_2018_Lyrics.csv", col.names = c("row_num", "artist", "title", "Title", "line", "lyric"))

# Concentrate just on the years for now. For this I create a distinction

clean_final <- left_join(clean_lyrics, clean_toplist) %>%
  select(year, Artist, Title, line, lyric) %>%
  distinct()

tokenized_lyrics <- clean_final %>%
  unnest_tokens(word, lyric)

write.csv(tokenized_lyrics, file = "Billboard_1970_2018_Tokenized_Lyrics.csv")


# Difference - song without lyrics ----------------------------------------

dist_toplist <- clean_toplist  %>% select(Title, Artist) %>% distinct()
dist_lyrics <- clean_lyrics %>% select(Title, Artist) %>% distinct()

difference <- dist_toplist %>%
  anti_join(dist_lyrics)
difference

# In the end, we will have around a 100 songs that we were unable to capture
# This shouldn't cause big issues for the main purpose of our analysis, as we still have more than 700 available.

rm(list = setdiff(ls(), "tokenized_lyrics"))

# Feature Engineering -----------------------------------------------------------

# I decided to save the working file, and load it after 
tokenized_lyrics <- read.csv("Billboard_1970_2018_Tokenized_Lyrics.csv")
tokenized_lyrics <- tokenized_lyrics %>% na.omit()

# Create the Decade variable
tokenized_lyrics <- tokenized_lyrics %>% 
  mutate(decade = ifelse(year >= 2010, "2010s",
                         ifelse(year >= 2000, "2000s",
                                ifelse(year >=1990, "1990s",
                                       ifelse(year >= 1980, "1980s", "1970s")))))



tokenized_lyrics %>% 
  count(word, sort = TRUE)

custom_stop_words <- bind_rows(tibble(word = c("ooh", "na", "ya", "la", "ey", "po", "oo", "tas", "ayy", "uh", "da", "whoa", "mmmm", "ayyy", "du",
                                               "su", "x6"),
                                      lexicon = c("custom")),
                               stop_words)

lyrics <- tokenized_lyrics %>% 
  anti_join(custom_stop_words)

lyrics %>% 
  count(word, sort = TRUE) %>% 
  top_n(10) %>% 
  ggplot(aes(reorder(word, -n), n)) +
  geom_bar(stat = "identity") +
  ylab("Number of Occurences") +
  xlab("Word")
ggsave("Charts/most_frequent_words.png", width=12, height=7.5)

# Let's see what the most used words are
# It looks like the most used words are related to love, girls, feelings and night


lyrics_decade_count <- lyrics %>% 
  group_by(decade) %>% 
  count(word, sort = TRUE)

decade_count <- setDT(lyrics_decade_count)
decade_count <- decade_count[, head(.SD, 10), by = decade]

decade_count %>% 
  ggplot(aes(reorder(word, -n), n, fill = decade)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~decade, ncol = 2, scales = "free_x") +
  ylab("Number of Occurences") +
  xlab("Word")
ggsave("Charts/most_frequent_words_by_decade.png", width=12, height=7.5)

# If we look at it by decade, we see very similar trends
# Even though some new words get introduced, the  ain ones look to be the same
# Can we draw the conclusion, that this is the winning receipt? Not so fast.

#wordcloud
lyrics %>% 
  count(word) %>% 
  with(wordcloud(word, n, max.words = 50))

# Sentiment ---------------------------------------------------------------

sentiment <- lyrics %>%
  inner_join(get_sentiments("bing")) %>%
  count(decade, year, sentiment) %>%
  spread(sentiment, n, fill = 0) %>%
  mutate(sentiment = positive - negative)

ggplot(sentiment, aes(year, sentiment, fill = decade)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~decade, ncol = 2, scales = "free_x")
ggsave("Charts/decade_sentiment.png", width=12, height=7.5)

# all 3 sentimkent packages

afinn <- lyrics %>% 
  inner_join(get_sentiments("afinn")) %>% 
  group_by(year) %>% 
  summarise(sentiment = sum(score)) %>% 
  mutate(method = "AFINN")

bing <- lyrics %>% 
  inner_join(get_sentiments("bing")) %>% 
  count(year, sentiment) %>% 
  spread(sentiment, n, fill = 0) %>% 
  mutate(sentiment = positive - negative,
         method = "BING")

nrc <- lyrics %>% 
  inner_join(get_sentiments("nrc") %>% 
               filter(sentiment %in% c("positive", "negative"))) %>% 
  count(year, sentiment) %>% 
  spread(sentiment, n, fill = 0) %>% 
  mutate(sentiment = positive - negative,
         method = "NRC")

all_sentiments <- bind_rows(nrc, bing, afinn)

# Visualize sentiment through time

all_sentiments %>% 
  ggplot(aes(year, sentiment, fill = method)) + 
  geom_col(show.legend = FALSE) +
  facet_wrap(~method, ncol = 1, scales = "free_y")
ggsave("Charts/sentiment_all_3_packages.png", width=12, height=7.5)

# Bing word counts

sentiment_word_counts <- lyrics %>% 
  inner_join(get_sentiments("bing")) %>% 
  count(word, sentiment, sort = TRUE) %>% 
  ungroup()

sentiment_word_counts %>% 
  group_by(sentiment) %>% 
  top_n(10) %>% 
  ungroup() %>% 
  mutate(word = reorder(word, n)) %>% 
  ggplot(aes(word, n, fill = sentiment)) +
  geom_col(show.legend = TRUE) +
  facet_wrap(~sentiment, scales = "free_y") +
  labs(y = "Contribution to sentiment",
       x = NULL) +
  coord_flip()
ggsave("Charts/sentiment_contributor_words.png", width=12, height=7.5)

# So what do we see in when looking into the sentiments. 
# Overall, the music seems to be of positive sentiment. We know that these sentiment lexocons contain more negative than positive words,
# But even with this bias, our songs seem to be more on the positive side. Obviously mentioning "Love" so many times has a great effect.

# Also, we can see how some major events influence the sentiments of our songs.
# As we all know correlation doesn't mean causation, however it looks pretty suspicious that in 1999, 2008 blabla maybe not



# Term frequency, tf-idf --------------------------------------------------

lyric_words <- lyrics %>% 
  count(decade, word, sort = TRUE) %>% 
  bind_tf_idf(word, decade, n)

lyric_words %>% 
  arrange(desc(tf_idf))

lyric_words %>%
  arrange(desc(tf_idf)) %>%
  mutate(word = factor(word, levels = rev(unique(word)))) %>% 
  group_by(decade) %>% 
  top_n(15) %>% 
  ungroup() %>%
  ggplot(aes(word, tf_idf, fill = decade)) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "tf-idf") +
  facet_wrap(~decade, ncol = 2, scales = "free") +
  coord_flip()
ggsave("Charts/tf_idf_words_in_decades.png", width=12, height=7.5)

# So far we have seen that throughout time, the words fdon't differ much. 
# However, are all these songs the same after all? What makes each decade unique?

# Based on analyzing term frequencies in the different decades, it seems like that where these songs differ - they don't actually differ that much.
# We see a lot of names mentioned in the 70s, but other than that most of these words are those of one or two very popular songs. 
# E.g. macarena is the 90s, Uptown Funk in the 10s and so on.


# DTM ---------------------------------------------------------------------

ap_sentiments <- lyric_words %>% 
  inner_join(get_sentiments("bing"))

ap_sentiments

ap_sentiments %>%
  count(sentiment, word, wt = n) %>%
  ungroup() %>%
  filter(n >= 100) %>%
  mutate(n = ifelse(sentiment == "negative", -n, n)) %>%
  mutate(word = reorder(word, n)) %>%
  ggplot(aes(word, n, fill = sentiment)) +
  geom_bar(stat = "identity") +
  ylab("Contribution to sentiment") +
  coord_flip()
ggsave("Charts/sentiment_contributor_words2.png", width=12, height=7.5)


year_term_count <- lyrics %>% 
  group_by(year) %>% 
  count(word, sort = TRUE) %>% 
  mutate(year_total = sum(n))



#Looking at the most frequent ones
year_term_count %>%
  filter(word %in% c("love", "baby", "girl", "time", "night", "feel")) %>%
  ggplot(aes(year, n / year_total)) +
  geom_point() +
  geom_smooth() +
  facet_wrap(~ word, scales = "free_y") +
  scale_y_continuous(labels = scales::percent_format()) +
  ylab("% frequency of word in inaugural address")
ggsave("Charts/usage_trend_most_frequent_words.png", width=12, height=7.5)

# Looking at those contributing most to the sentiment
year_term_count %>%
  filter(word %in% c("love", "hot", "boom", "bad", "break", "wild")) %>%
  ggplot(aes(year, n / year_total)) +
  geom_point() +
  geom_smooth() +
  facet_wrap(~ word, scales = "free_y") +
  scale_y_continuous(labels = scales::percent_format()) +
  ylab("% frequency of word in inaugural address")
ggsave("Charts/usage_trend_most_sentimental_words.png", width=12, height=7.5)

# Ones with high tf/idf - useless
year_term_count %>%
  filter(word %in% c("ron", "physical", "romantic", "bum", "mum", "hol")) %>%
  ggplot(aes(year, n / year_total)) +
  geom_point() +
  geom_smooth() +
  facet_wrap(~ word, scales = "free_y") +
  scale_y_continuous(labels = scales::percent_format()) +
  ylab("% frequency of word in inaugural address")

# Topic Modeling ----------------------------------------------------------

lyricDTM <- year_term_count %>% 
  cast_dtm(year, word, n)

year_lda <- LDA(lyricDTM, k = 2, control = list(seed = 42))

topics <- tidy(year_lda, matrix = "beta")

topic_words <- topics %>%
  group_by(topic) %>%
  top_n(10, beta) %>%
  ungroup() %>%
  arrange(topic, -beta)

topic_words %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip()
ggsave("Charts/yearly_topic_modeling_2.png", width=12, height=7.5)

# Same for Decades --------------------------------------------------------

decade_term_count <- lyrics %>% 
  group_by(decade) %>% 
  count(word, sort = TRUE) %>% 
  mutate(decade_total = sum(n))

decadeLyricDTM <- decade_term_count %>% 
  cast_dtm(decade, word, n)

decade_lda <- LDA(decadeLyricDTM, k = 2, control = list(seed = 42))

decade_topics <- tidy(decade_lda, matrix = "beta")

decade_topic_words <- decade_topics %>%
  group_by(topic) %>%
  top_n(10, beta) %>%
  ungroup() %>%
  arrange(topic, -beta)

decade_topic_words %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip()
ggsave("Charts/decade_topic_modeling.png", width=12, height=7.5)

# Topic modeling does nothing. It seems like the topic is always the same.
# Same old boring topics are being brought up each and every year and decade

beta_spread <- decade_topics %>%
  mutate(topic = paste0("topic", topic)) %>%
  spread(topic, beta) %>%
  filter(topic1 > .001 | topic2 > .001) %>%
  mutate(log_ratio = log2(topic2 / topic1))

beta_spread

beta_spread %>% 
  mutate(topic_num = ifelse(log_ratio > 0 , "Topic 2", "Topic 1")) %>% 
  filter(log_ratio > 20 | log_ratio < -20) %>% 
  mutate(term = reorder(term, log_ratio)) %>% 
  ggplot(aes(term, log_ratio, fill = topic_num)) +
  geom_col(show.legend = TRUE) +
  labs(y = "Uniqueness in Topic",
       x = NULL) +
  coord_flip()
ggsave("Charts/topic_unique_words.png", width=12, height=7.5)

# It seems like names are the differentiators mostly in topics. 


decade_topics_gamma <- tidy(decade_lda, matrix = "gamma")
decade_topics_gamma

