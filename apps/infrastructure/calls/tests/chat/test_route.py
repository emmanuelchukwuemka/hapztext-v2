"""
Test Calls route
"""

import pytest
from rest_framework.test import APIClient


@pytest.mark.django_db
class TestCallsRoute:
    """
    TestCallsRoute
    """

    def test_a_create_call_returns_201(self, participants, auth_client_fx: APIClient):
        """
        Test create call success. returns 201
        """

        response = auth_client_fx.post(
            "/api/v1/calls", data={"participant_ids": [participants[1].id]}
        )
        assert response.status_code == 201  # type: ignore
        data = response.json()  # type: ignore
        print("data: ", data)

        assert data["data"]

    def test_b_when_invalid_participant_returns_404(self, auth_client_fx: APIClient):
        """
        Test create call returns 400 when invalid participant
        """
        response = auth_client_fx.post(
            "/api/v1/calls",
            data={"participant_ids": ["123456789123456789012"]},
        )

        assert response.status_code == 404  # type: ignore

        data = response.json()  # type: ignore

        print("data: ", data)

        assert data["message"] == "Call Participant does not exist"

    def test_c_when_invalid_participant_id_too_short_returns_400(
        self, auth_client_fx: APIClient
    ):
        """
        Test create call returns 400 when invalid participant ID
        """
        response = auth_client_fx.post(
            "/api/v1/calls",
            data={"participant_ids": ["123456789"]},
        )

        assert response.status_code == 400  # type: ignore

        data = response.json()  # type: ignore

        print("data: ", data)

        assert data["message"] == "Validation error"
        assert data["errors"] == [
            {
                "participant_ids": {
                    "0": ["Ensure this field has at least 21 characters."]
                }
            }
        ]

    def test_d_when_invalid_call_type_returns_400(self, auth_client_fx: APIClient):
        """
        test  when invalid call type returns 400
        """
        response = auth_client_fx.post(
            "/api/v1/calls",
            data={"call_type": ["123456789"]},
        )

        assert response.status_code == 400  # type: ignore

        data = response.json()  # type: ignore

        print("data: ", data)

        assert data["message"] == "Validation error"
        assert data["errors"] == [{"call_type": ['"123456789" is not a valid choice.']}]

    def test_e_when_title_too_long_returns_400(self, auth_client_fx: APIClient):
        """
        test  when title too long returns 400
        """
        response = auth_client_fx.post(
            "/api/v1/calls",
            data={
                "title": [
                    "1234567sssssssssssss8911111111111111111111111111111111111111111234567891111111111111111111111111111111111111111"
                ]
            },
        )

        assert response.status_code == 400  # type: ignore

        data = response.json()  # type: ignore

        print("data: ", data)

        assert data["message"] == "Validation error"
        assert data["errors"] == [
            {"title": ["Ensure this field has no more than 100 characters."]}
        ]
