class Usr {
  final int id;
  final String name;
  final String imgUrl;

  Usr({required this.id, required this.name, required this.imgUrl});
}

//YOU - current user
final Usr currentUser = Usr(id: 0, name: 'You', imgUrl: 'assets/images/me.jpg');

//USERS
final Usr asta = Usr(id: 1, name: 'Asta', imgUrl: 'assets/images/asta.jpg');
final Usr glory = Usr(id: 2, name: 'Fortune', imgUrl: 'assets/images/me.jpg');
final Usr yuno = Usr(id: 3, name: 'Yuno', imgUrl: 'assets/images/yuno.jpg');
final Usr uche =
    Usr(id: 4, name: 'Uche', imgUrl: 'assets/images/chukwuchi.jpg');
final Usr john = Usr(id: 5, name: 'John', imgUrl: 'assets/images/vegeta.jpg');
final Usr sasuke =
    Usr(id: 6, name: 'Sasuke', imgUrl: 'assets/images/sasuke.jpg');

List<Usr> favorites = [yuno, sasuke, asta, uche, glory, john, asta];
