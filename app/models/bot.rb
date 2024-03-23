class Bot < User
  default_scope -> {where(is_bot: true)}

end