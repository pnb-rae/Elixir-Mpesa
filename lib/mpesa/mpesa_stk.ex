defmodule Mpesa.MpesaStk do
  @moduledoc """
  A module responsible for handling STK push requests to the Mpesa API.
  """

  alias Mpesa.MpesaAuth

  require Logger

  @pass_key System.get_env("MPESA_PASS_KEY")
  @short_code "174379"

  def initiate_payment(phone_number, amount) do
    {:ok, mpesa_token} = MpesaAuth.generate_token()
    headers = build_headers(mpesa_token)
    body = generate_body(phone_number, amount)

    response =
      Finch.build(:post, url(), headers, body)
      |> Finch.request(Mpesa.Finch)

    case response do
      {:ok, %Finch.Response{status: 200, body: resp_body}} ->
        Logger.info("Initiated payment successfully")
        {:ok, resp_body |> Jason.decode!()}

      {:ok, %Finch.Response{status: _status, body: resp_body}} ->
        resp_body |> Jason.decode!()

      {:error, _reason} ->
        {:error, "Failed to initiate payment"}
    end
  end

  @doc false
  defp generate_body(phone_number, amount) do
    timestamp = get_timestamp()
    password = generate_stk_password()
    transaction_reference = generate_transaction_reference()

    %{
      BusinessShortCode: @short_code,
      Password: password,
      Timestamp: timestamp,
      TransactionType: "CustomerPayBillOnline",
      Amount: amount,
      PartyA: phone_number,
      PartyB: @short_code,
      PhoneNumber: phone_number,
      CallBackURL: "https://9e55-41-212-115-150.ngrok-free.app/api/callback",
      AccountReference: transaction_reference,
      TransactionDesc: "Test"
    }
    |> Jason.encode!()
  end

  def build_headers(token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
  end

  # Generate stk password to be passed as one of the required body parameters.
  # This is the Base64-encoded value of the concatenation of the Shortcode + Passkey + Timestamp
  @doc false
  defp generate_stk_password do
    timestamp = get_timestamp()
    Base.encode64("#{@short_code}#{@pass_key}#{timestamp}")
  end

  ## generate timestamp
  @doc false
  defp get_timestamp do
    Timex.local()
    |> Timex.format!("{YYYY}{0M}{0D}{h24}{m}{s}")
  end

  @doc false
  defp generate_transaction_reference do
    :crypto.strong_rand_bytes(7) |> Base.encode16()
  end

  @doc false
  defp url, do: "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
end
