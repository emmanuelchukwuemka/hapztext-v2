from rest_framework import serializers


class SuccessResponseExampleSerializer(serializers.Serializer):
    success = serializers.BooleanField(read_only=True, default=True)
    message = serializers.CharField(read_only=True)
    data = serializers.DictField(read_only=True)
    status_code = serializers.IntegerField(read_only=True)


class ErrorResponseExampleSerializer(serializers.Serializer):
    success = serializers.BooleanField(read_only=True, default=False)
    message = serializers.CharField(read_only=True)
    errors = serializers.DictField(read_only=True)
    status_code = serializers.IntegerField(read_only=True)
