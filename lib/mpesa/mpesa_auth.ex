defmodule Mpesa.MpesaAuth do
  @moduledoc """
  A module responsible for handling authentication with the Mpesa API.

  This module provides functionality to generate an access token using the
  OAuth client credentials flow. The access token is required for making
  authorized API requests to any the Mpesa API.  
  """

  require Logger

  @consumer_key System.get_env("MPESA_CONSUMER_KEY")
  @consumer_secret System.get_env("MPESA_CONSUMER_SECRET")

  @doc """
   ## Functions

   - `generate_token/0`: Requests a time-bound access token using the client
   credentials and returns the token along with its expiry time.

  ## Example

   {:ok, token} = MpesaAuth.generate_token()

  """
  def generate_token do
    url = url()
    headers = get_headers()

    response =
      Finch.build(:get, url, headers)
      |> Finch.request(Mpesa.Finch)

    case response do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        access_token = body |> Jason.decode!() |> Map.get("access_token")
        {:ok, access_token}

      {:ok, %Finch.Response{status: status, body: _body}} ->
        {:error, "Failed to generate token. Status: #{status}"}

      {:error, reason} ->
        Logger.error("Token generation failed: #{inspect(reason)}")
        {:error, "Authentication error"}
    end
  end

  @doc false
  defp url, do: "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"

  @doc false
  defp get_headers do
    encoded_credentials = encode_credentials()

    [
      {"Authorization", "Basic #{encoded_credentials}"},
      {"Content-Type", "application/json"}
    ]
  end

  @doc false
  defp encode_credentials do
    Base.encode64("#{@consumer_key}:#{@consumer_secret}")
  end
end
