-- Fix: resolve ambiguous "user_id" column reference in mark_messages_as_read
--
-- The previous version of this function caused:
--   PostgrestException(message: column reference "user_id" is ambiguous,
--                      code: 42702,
--                      details: It could refer to either a PL/pgSQL variable
--                               or a table column.)
--
-- Root cause: the parameter was named "user_id", which is the same name as the
-- "user_id" column in the messages / conversation_participants tables.
-- PostgreSQL could not determine whether "user_id" in the WHERE clause referred
-- to the function parameter or to the table column.
--
-- Fix: prefix every function parameter with "p_" so the names are distinct from
-- the table column names, and qualify every column reference with its table name.

CREATE OR REPLACE FUNCTION mark_messages_as_read(
    p_conversation_id uuid,
    p_user_id         uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Mark all unread messages in this conversation as read,
    -- but only for messages that were NOT sent by the current user.
    -- Using fully-qualified "messages.sender_id" to avoid any ambiguity.
    UPDATE messages
    SET is_read = true
    WHERE messages.conversation_id = p_conversation_id
      AND messages.sender_id      <> p_user_id
      AND messages.is_read         = false;
END;
$$;

-- Grant execute permission to authenticated users only
REVOKE EXECUTE ON FUNCTION mark_messages_as_read(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION mark_messages_as_read(uuid, uuid) TO authenticated;
