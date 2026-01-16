defmodule MpesaWeb.MpesaController do
  use MpesaWeb, :controller

  require Logger
  # Handle successful transactions
  def handle_callback(conn, %{
        "Body" => %{
          "stkCallback" => %{
            "CheckoutRequestID" => _checkout_request_id,
            "MerchantRequestID" => _merchant_request_id,
            "ResultCode" => 0,
            "ResultDesc" => _result_desc,
            "CallbackMetadata" => %{
              "Item" => _items
            }
          }
        }
      }) do
    Logger.info("Successful transaction:")

    json(conn, %{"status" => "ok"})
  end

  # Handle unsuccessful transactions
  def handle_callback(conn, %{
        "Body" => %{
          "stkCallback" => %{
            "CheckoutRequestID" => _checkout_request_id,
            "MerchantRequestID" => _merchant_request_id,
            "ResultCode" => result_code,
            "ResultDesc" => _result_desc
          }
        }
      })
      when result_code != 0 do
    Logger.warning("Unsuccessful transaction:")

    json(conn, %{
      "status" => "ok"
    })
  end

  # Handle unexpected payloads
  def handle_callback(conn, _params) do
    json(conn, %{"status" => "error", "message" => "Invalid payload"})
  end
end
