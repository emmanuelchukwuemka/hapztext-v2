import factory
from factory import post_generation
from django.contrib.auth import get_user_model
from apps.infrastructure.users.models.tables import UserProfile, UserFollowing
from apps.infrastructure.authentication.models.tables import OTPCode
from apps.infrastructure.posts.models.tables import Post, PostReaction, PostShare, PostTag
from apps.infrastructure.notifications.models.tables import Notification, NotificationPreferences
from apps.infrastructure.chat.models.tables import Conversation, Message, ConversationParticipant
from apps.domain.posts.enums import PostFormat
from apps.domain.chat.enums import ConversationType, MessageType, MessageStatus
from apps.domain.notifications.enums import NotificationType

User = get_user_model()

class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User
        django_get_or_create = ('email',)

    username = factory.Sequence(lambda n: f'user_{n}')
    email = factory.Sequence(lambda n: f'user_{n}@example.com')
    is_email_verified = True

    @post_generation
    def password(self, create, extracted, **kwargs):
        password = extracted or 'password123'
        self.set_password(password)

class UserProfileFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = UserProfile

    user = factory.SubFactory(UserFactory)
    first_name = factory.Faker('first_name')
    last_name = factory.Faker('last_name')

class OTPCodeFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = OTPCode

    user = factory.SubFactory(UserFactory)
    code = '123456'

class PostFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Post

    sender = factory.SubFactory(UserFactory)
    text_content = factory.Faker('text')
    post_format = PostFormat.TEXT

class ConversationFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Conversation

    conversation_type = ConversationType.PRIVATE

class MessageFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Message

    conversation = factory.SubFactory(ConversationFactory)
    sender = factory.SubFactory(UserFactory)
    text_content = factory.Faker('text')
    message_type = MessageType.TEXT

class NotificationFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Notification

    recipient = factory.SubFactory(UserFactory)
    sender = factory.SubFactory(UserFactory)
    message = factory.Faker('sentence')
    notification_type = NotificationType.POST_CREATED.value

class ConversationParticipantFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = ConversationParticipant

    conversation = factory.SubFactory(ConversationFactory)
    user = factory.SubFactory(UserFactory)
