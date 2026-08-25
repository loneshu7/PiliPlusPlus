// ignore_for_file: constant_identifier_names
enum SearchType {
  video('视频'),
  media_bangumi('番剧'),
  media_ft('影视'),
  live_room('直播间'),
  bili_user('用户'),
  article('专栏'),
  ;

  final String label;
  const SearchType(this.label);
}
