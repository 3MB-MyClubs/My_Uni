export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      academic_years: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          name: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
      app_admins: {
        Row: {
          auth_user_id: string
          created_at: string
          email: string
          singleton: boolean
        }
        Insert: {
          auth_user_id: string
          created_at?: string
          email: string
          singleton?: boolean
        }
        Update: {
          auth_user_id?: string
          created_at?: string
          email?: string
          singleton?: boolean
        }
        Relationships: []
      }
      app_update_config: {
        Row: {
          android_min_build: number
          android_store_url: string
          id: string
          ios_min_build: number
          ios_store_url: string
          updated_at: string
        }
        Insert: {
          android_min_build?: number
          android_store_url?: string
          id: string
          ios_min_build?: number
          ios_store_url?: string
          updated_at?: string
        }
        Update: {
          android_min_build?: number
          android_store_url?: string
          id?: string
          ios_min_build?: number
          ios_store_url?: string
          updated_at?: string
        }
        Relationships: []
      }
      chat_v2_change_log: {
        Row: {
          change_id: number
          changed_at: string
          club_id: string | null
          club_inbox_profile_id: string | null
          direct_receiver_id: string | null
          direct_sender_id: string | null
          group_id: string | null
          message_id: string
          operation: string
          record: Json
          record_type: string
          thread_id: string
        }
        Insert: {
          change_id?: never
          changed_at?: string
          club_id?: string | null
          club_inbox_profile_id?: string | null
          direct_receiver_id?: string | null
          direct_sender_id?: string | null
          group_id?: string | null
          message_id: string
          operation: string
          record: Json
          record_type?: string
          thread_id: string
        }
        Update: {
          change_id?: never
          changed_at?: string
          club_id?: string | null
          club_inbox_profile_id?: string | null
          direct_receiver_id?: string | null
          direct_sender_id?: string | null
          group_id?: string | null
          message_id?: string
          operation?: string
          record?: Json
          record_type?: string
          thread_id?: string
        }
        Relationships: []
      }
      chat_v2_read_state: {
        Row: {
          last_read_created_at: string
          last_read_message_id: string
          read_scope: string
          thread_id: string
          updated_at: string
          viewer_id: string
        }
        Insert: {
          last_read_created_at: string
          last_read_message_id: string
          read_scope?: string
          thread_id: string
          updated_at?: string
          viewer_id: string
        }
        Update: {
          last_read_created_at?: string
          last_read_message_id?: string
          read_scope?: string
          thread_id?: string
          updated_at?: string
          viewer_id?: string
        }
        Relationships: []
      }
      club_account_contexts: {
        Row: {
          club_id: string
          created_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          club_id: string
          created_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          club_id?: string
          created_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "club_account_contexts_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      club_auth_accounts: {
        Row: {
          auth_user_id: string
          club_id: string
          created_at: string
        }
        Insert: {
          auth_user_id: string
          club_id: string
          created_at?: string
        }
        Update: {
          auth_user_id?: string
          club_id?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "club_auth_accounts_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      club_blocks: {
        Row: {
          blocker_id: string
          club_id: string
          created_at: string
        }
        Insert: {
          blocker_id: string
          club_id: string
          created_at?: string
        }
        Update: {
          blocker_id?: string
          club_id?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "club_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_blocks_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      club_categories: {
        Row: {
          created_at: string
          description: string | null
          icon_name: string | null
          id: string
          is_active: boolean
          name: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          description?: string | null
          icon_name?: string | null
          id?: string
          is_active?: boolean
          name: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          description?: string | null
          icon_name?: string | null
          id?: string
          is_active?: boolean
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
      club_channel_messages: {
        Row: {
          ciphertext: string | null
          club_id: string
          content: string
          created_at: string
          crypto_version: number | null
          id: string
          key_version: number | null
          mac: string | null
          message_kind: string
          nonce: string | null
          payload: Json
          sender_auth_id: string
          sender_club_id: string | null
          sender_device_id: string | null
          sender_profile_id: string | null
          signature: string | null
        }
        Insert: {
          ciphertext?: string | null
          club_id: string
          content?: string
          created_at?: string
          crypto_version?: number | null
          id?: string
          key_version?: number | null
          mac?: string | null
          message_kind?: string
          nonce?: string | null
          payload?: Json
          sender_auth_id: string
          sender_club_id?: string | null
          sender_device_id?: string | null
          sender_profile_id?: string | null
          signature?: string | null
        }
        Update: {
          ciphertext?: string | null
          club_id?: string
          content?: string
          created_at?: string
          crypto_version?: number | null
          id?: string
          key_version?: number | null
          mac?: string | null
          message_kind?: string
          nonce?: string | null
          payload?: Json
          sender_auth_id?: string
          sender_club_id?: string | null
          sender_device_id?: string | null
          sender_profile_id?: string | null
          signature?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "club_channel_messages_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_channel_messages_sender_club_id_fkey"
            columns: ["sender_club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_channel_messages_sender_device_id_fkey"
            columns: ["sender_device_id"]
            isOneToOne: false
            referencedRelation: "e2ee_devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_channel_messages_sender_profile_id_fkey"
            columns: ["sender_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      club_channel_poll_votes: {
        Row: {
          created_at: string
          message_id: string
          option_index: number
          updated_at: string
          voter_auth_id: string
        }
        Insert: {
          created_at?: string
          message_id: string
          option_index: number
          updated_at?: string
          voter_auth_id: string
        }
        Update: {
          created_at?: string
          message_id?: string
          option_index?: number
          updated_at?: string
          voter_auth_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "club_channel_poll_votes_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "club_channel_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      club_followers: {
        Row: {
          club_id: string
          created_at: string
          id: string
          profile_id: string
          role: string
          role_title: string | null
        }
        Insert: {
          club_id: string
          created_at?: string
          id?: string
          profile_id: string
          role?: string
          role_title?: string | null
        }
        Update: {
          club_id?: string
          created_at?: string
          id?: string
          profile_id?: string
          role?: string
          role_title?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "club_followers_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_followers_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      club_inbox_messages: {
        Row: {
          ciphertext: string | null
          content: string
          created_at: string
          crypto_version: number | null
          delivered_at: string
          id: string
          key_version: number | null
          mac: string | null
          message_kind: string
          nonce: string | null
          payload: Json
          seen_at: string | null
          sender_auth_id: string
          sender_club_id: string | null
          sender_device_id: string | null
          sender_profile_id: string | null
          signature: string | null
          thread_id: string
        }
        Insert: {
          ciphertext?: string | null
          content?: string
          created_at?: string
          crypto_version?: number | null
          delivered_at?: string
          id?: string
          key_version?: number | null
          mac?: string | null
          message_kind?: string
          nonce?: string | null
          payload?: Json
          seen_at?: string | null
          sender_auth_id: string
          sender_club_id?: string | null
          sender_device_id?: string | null
          sender_profile_id?: string | null
          signature?: string | null
          thread_id: string
        }
        Update: {
          ciphertext?: string | null
          content?: string
          created_at?: string
          crypto_version?: number | null
          delivered_at?: string
          id?: string
          key_version?: number | null
          mac?: string | null
          message_kind?: string
          nonce?: string | null
          payload?: Json
          seen_at?: string | null
          sender_auth_id?: string
          sender_club_id?: string | null
          sender_device_id?: string | null
          sender_profile_id?: string | null
          signature?: string | null
          thread_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "club_inbox_messages_sender_club_id_fkey"
            columns: ["sender_club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_inbox_messages_sender_device_id_fkey"
            columns: ["sender_device_id"]
            isOneToOne: false
            referencedRelation: "e2ee_devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_inbox_messages_sender_profile_id_fkey"
            columns: ["sender_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_inbox_messages_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "club_inbox_threads"
            referencedColumns: ["id"]
          },
        ]
      }
      club_inbox_threads: {
        Row: {
          club_id: string
          created_at: string
          id: string
          profile_id: string
          updated_at: string
        }
        Insert: {
          club_id: string
          created_at?: string
          id?: string
          profile_id: string
          updated_at?: string
        }
        Update: {
          club_id?: string
          created_at?: string
          id?: string
          profile_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "club_inbox_threads_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_inbox_threads_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      club_posts: {
        Row: {
          author_id: string | null
          club_id: string
          content: string
          created_at: string
          id: string
          image_path: string | null
          image_url: string | null
          is_announcement: boolean
          updated_at: string
        }
        Insert: {
          author_id?: string | null
          club_id: string
          content: string
          created_at?: string
          id?: string
          image_path?: string | null
          image_url?: string | null
          is_announcement?: boolean
          updated_at?: string
        }
        Update: {
          author_id?: string | null
          club_id?: string
          content?: string
          created_at?: string
          id?: string
          image_path?: string | null
          image_url?: string | null
          is_announcement?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "club_posts_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "club_posts_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      clubs: {
        Row: {
          category_id: string | null
          created_at: string
          description: string | null
          email: string | null
          id: string
          is_active: boolean
          logo_url: string | null
          name: string
          short_name: string | null
          tes: boolean | null
          updated_at: string
        }
        Insert: {
          category_id?: string | null
          created_at?: string
          description?: string | null
          email?: string | null
          id?: string
          is_active?: boolean
          logo_url?: string | null
          name: string
          short_name?: string | null
          tes?: boolean | null
          updated_at?: string
        }
        Update: {
          category_id?: string | null
          created_at?: string
          description?: string | null
          email?: string | null
          id?: string
          is_active?: boolean
          logo_url?: string | null
          name?: string
          short_name?: string | null
          tes?: boolean | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "clubs_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "club_categories"
            referencedColumns: ["id"]
          },
        ]
      }
      direct_messages: {
        Row: {
          ciphertext: string | null
          content: string
          created_at: string
          crypto_version: number | null
          delivered_at: string
          id: string
          key_version: number | null
          legacy_plaintext: boolean
          mac: string | null
          message_kind: string
          nonce: string | null
          payload: Json
          read_at: string | null
          receiver_id: string
          seen_at: string | null
          sender_device_id: string | null
          sender_id: string
          signature: string | null
        }
        Insert: {
          ciphertext?: string | null
          content: string
          created_at?: string
          crypto_version?: number | null
          delivered_at?: string
          id?: string
          key_version?: number | null
          legacy_plaintext?: boolean
          mac?: string | null
          message_kind?: string
          nonce?: string | null
          payload?: Json
          read_at?: string | null
          receiver_id: string
          seen_at?: string | null
          sender_device_id?: string | null
          sender_id: string
          signature?: string | null
        }
        Update: {
          ciphertext?: string | null
          content?: string
          created_at?: string
          crypto_version?: number | null
          delivered_at?: string
          id?: string
          key_version?: number | null
          legacy_plaintext?: boolean
          mac?: string | null
          message_kind?: string
          nonce?: string | null
          payload?: Json
          read_at?: string | null
          receiver_id?: string
          seen_at?: string | null
          sender_device_id?: string | null
          sender_id?: string
          signature?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "direct_messages_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "direct_messages_sender_device_id_fkey"
            columns: ["sender_device_id"]
            isOneToOne: false
            referencedRelation: "e2ee_devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "direct_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      e2ee_devices: {
        Row: {
          algorithm: string
          created_at: string
          encryption_public_key: string
          id: string
          last_seen_at: string
          owner_auth_id: string
          revoked_at: string | null
          signing_public_key: string
        }
        Insert: {
          algorithm?: string
          created_at?: string
          encryption_public_key: string
          id: string
          last_seen_at?: string
          owner_auth_id: string
          revoked_at?: string | null
          signing_public_key: string
        }
        Update: {
          algorithm?: string
          created_at?: string
          encryption_public_key?: string
          id?: string
          last_seen_at?: string
          owner_auth_id?: string
          revoked_at?: string | null
          signing_public_key?: string
        }
        Relationships: []
      }
      e2ee_thread_key_envelopes: {
        Row: {
          created_at: string
          ephemeral_public_key: string
          key_version: number
          mac: string
          nonce: string
          recipient_auth_id: string
          recipient_device_id: string
          sender_device_id: string
          signature: string
          thread_id: string
          wrapped_key: string
        }
        Insert: {
          created_at?: string
          ephemeral_public_key: string
          key_version: number
          mac: string
          nonce: string
          recipient_auth_id: string
          recipient_device_id: string
          sender_device_id: string
          signature: string
          thread_id: string
          wrapped_key: string
        }
        Update: {
          created_at?: string
          ephemeral_public_key?: string
          key_version?: number
          mac?: string
          nonce?: string
          recipient_auth_id?: string
          recipient_device_id?: string
          sender_device_id?: string
          signature?: string
          thread_id?: string
          wrapped_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "e2ee_thread_key_envelopes_recipient_device_id_fkey"
            columns: ["recipient_device_id"]
            isOneToOne: false
            referencedRelation: "e2ee_devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "e2ee_thread_key_envelopes_sender_device_id_fkey"
            columns: ["sender_device_id"]
            isOneToOne: false
            referencedRelation: "e2ee_devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "e2ee_thread_key_envelopes_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "e2ee_threads"
            referencedColumns: ["thread_id"]
          },
        ]
      }
      e2ee_threads: {
        Row: {
          created_at: string
          created_by: string
          current_key_version: number
          rotated_at: string
          thread_id: string
        }
        Insert: {
          created_at?: string
          created_by: string
          current_key_version?: number
          rotated_at?: string
          thread_id: string
        }
        Update: {
          created_at?: string
          created_by?: string
          current_key_version?: number
          rotated_at?: string
          thread_id?: string
        }
        Relationships: []
      }
      event_checkins: {
        Row: {
          checked_in_at: string
          checked_in_by: string | null
          event_id: string
          id: string
          legacy_checked_in_by: string | null
          method: string
          profile_id: string
        }
        Insert: {
          checked_in_at?: string
          checked_in_by?: string | null
          event_id: string
          id?: string
          legacy_checked_in_by?: string | null
          method?: string
          profile_id: string
        }
        Update: {
          checked_in_at?: string
          checked_in_by?: string | null
          event_id?: string
          id?: string
          legacy_checked_in_by?: string | null
          method?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_checkins_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_checkins_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      event_rsvps: {
        Row: {
          created_at: string
          event_id: string
          id: string
          profile_id: string
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          profile_id: string
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_rsvps_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_rsvps_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          club_id: string
          created_at: string
          created_by_user_id: string | null
          description: string | null
          ends_at: string | null
          event_date: string
          id: string
          image_path: string | null
          image_url: string | null
          is_public: boolean
          location: string | null
          registration_url: string | null
          schedule: Json | null
          speakers: Json | null
          starts_at: string
          tags: string[]
          title: string
          updated_at: string
        }
        Insert: {
          club_id: string
          created_at?: string
          created_by_user_id?: string | null
          description?: string | null
          ends_at?: string | null
          event_date: string
          id?: string
          image_path?: string | null
          image_url?: string | null
          is_public?: boolean
          location?: string | null
          registration_url?: string | null
          schedule?: Json | null
          speakers?: Json | null
          starts_at: string
          tags?: string[]
          title: string
          updated_at?: string
        }
        Update: {
          club_id?: string
          created_at?: string
          created_by_user_id?: string | null
          description?: string | null
          ends_at?: string | null
          event_date?: string
          id?: string
          image_path?: string | null
          image_url?: string | null
          is_public?: boolean
          location?: string | null
          registration_url?: string | null
          schedule?: Json | null
          speakers?: Json | null
          starts_at?: string
          tags?: string[]
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "events_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      group_chat_members: {
        Row: {
          group_id: string
          joined_at: string
          position: number
          user_id: string
        }
        Insert: {
          group_id: string
          joined_at?: string
          position?: number
          user_id: string
        }
        Update: {
          group_id?: string
          joined_at?: string
          position?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_chat_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "group_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_chat_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_chats: {
        Row: {
          admin_ids: string[]
          created_at: string
          creator_id: string
          custom_name: string | null
          id: string
          photo_url: string | null
          updated_at: string
        }
        Insert: {
          admin_ids?: string[]
          created_at?: string
          creator_id: string
          custom_name?: string | null
          id?: string
          photo_url?: string | null
          updated_at?: string
        }
        Update: {
          admin_ids?: string[]
          created_at?: string
          creator_id?: string
          custom_name?: string | null
          id?: string
          photo_url?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_chats_creator_id_fkey"
            columns: ["creator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_message_receipts: {
        Row: {
          delivered_at: string | null
          message_id: string
          seen_at: string | null
          user_id: string
        }
        Insert: {
          delivered_at?: string | null
          message_id: string
          seen_at?: string | null
          user_id: string
        }
        Update: {
          delivered_at?: string | null
          message_id?: string
          seen_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_message_receipts_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "group_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_message_receipts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_messages: {
        Row: {
          ciphertext: string | null
          content: string
          created_at: string
          crypto_version: number | null
          group_id: string
          id: string
          key_version: number | null
          legacy_plaintext: boolean
          mac: string | null
          message_kind: string
          nonce: string | null
          payload: Json
          sender_device_id: string | null
          sender_id: string
          signature: string | null
        }
        Insert: {
          ciphertext?: string | null
          content: string
          created_at?: string
          crypto_version?: number | null
          group_id: string
          id?: string
          key_version?: number | null
          legacy_plaintext?: boolean
          mac?: string | null
          message_kind?: string
          nonce?: string | null
          payload?: Json
          sender_device_id?: string | null
          sender_id: string
          signature?: string | null
        }
        Update: {
          ciphertext?: string | null
          content?: string
          created_at?: string
          crypto_version?: number | null
          group_id?: string
          id?: string
          key_version?: number | null
          legacy_plaintext?: boolean
          mac?: string | null
          message_kind?: string
          nonce?: string | null
          payload?: Json
          sender_device_id?: string | null
          sender_id?: string
          signature?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_messages_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "group_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_messages_sender_device_id_fkey"
            columns: ["sender_device_id"]
            isOneToOne: false
            referencedRelation: "e2ee_devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      interests: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          name: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
      majors: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          name: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
      moderation_reports: {
        Row: {
          action_notes: string | null
          content_snapshot: string | null
          created_at: string
          id: string
          reason: string
          reported_user_id: string | null
          reporter_id: string
          reviewed_at: string | null
          reviewed_by: string | null
          source: string
          status: string
          target_id: string
          target_type: string
        }
        Insert: {
          action_notes?: string | null
          content_snapshot?: string | null
          created_at?: string
          id?: string
          reason: string
          reported_user_id?: string | null
          reporter_id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          source?: string
          status?: string
          target_id: string
          target_type: string
        }
        Update: {
          action_notes?: string | null
          content_snapshot?: string | null
          created_at?: string
          id?: string
          reason?: string
          reported_user_id?: string | null
          reporter_id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          source?: string
          status?: string
          target_id?: string
          target_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "moderation_reports_reported_user_id_fkey"
            columns: ["reported_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "moderation_reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "moderation_reports_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_deliveries_v2: {
        Row: {
          attempt_count: number
          created_at: string
          delivered_at: string | null
          device_id: string
          id: string
          last_error: string | null
          last_error_code: string | null
          last_http_status: number | null
          lease_expires_at: string | null
          lease_owner: string | null
          lease_token: string | null
          next_attempt_at: string
          notification_id: string
          outbox_id: string
          provider_message_id: string | null
          recipient_id: string
          status: string
          terminal_at: string | null
          updated_at: string
        }
        Insert: {
          attempt_count?: number
          created_at?: string
          delivered_at?: string | null
          device_id: string
          id?: string
          last_error?: string | null
          last_error_code?: string | null
          last_http_status?: number | null
          lease_expires_at?: string | null
          lease_owner?: string | null
          lease_token?: string | null
          next_attempt_at?: string
          notification_id: string
          outbox_id: string
          provider_message_id?: string | null
          recipient_id: string
          status?: string
          terminal_at?: string | null
          updated_at?: string
        }
        Update: {
          attempt_count?: number
          created_at?: string
          delivered_at?: string | null
          device_id?: string
          id?: string
          last_error?: string | null
          last_error_code?: string | null
          last_http_status?: number | null
          lease_expires_at?: string | null
          lease_owner?: string | null
          lease_token?: string | null
          next_attempt_at?: string
          notification_id?: string
          outbox_id?: string
          provider_message_id?: string | null
          recipient_id?: string
          status?: string
          terminal_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_deliveries_v2_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "push_devices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_deliveries_v2_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_deliveries_v2_outbox_id_recipient_id_fkey"
            columns: ["outbox_id", "recipient_id"]
            isOneToOne: false
            referencedRelation: "notification_recipients_v2"
            referencedColumns: ["outbox_id", "recipient_id"]
          },
        ]
      }
      notification_outbox_v2: {
        Row: {
          actor_user_id: string | null
          attempt_count: number
          audience_data: Json
          audience_id: string | null
          audience_type: string
          batch_count: number
          body: string
          completed_at: string | null
          created_at: string
          event_key: string
          id: string
          last_error: string | null
          last_error_code: string | null
          lease_expires_at: string | null
          lease_owner: string | null
          lease_token: string | null
          localization_args: Json
          next_attempt_at: string
          notification_group_key: string | null
          notification_type: string
          recipient_count: number
          recipient_cursor: string | null
          status: string
          target_id: string
          target_type: string
          title: string
          updated_at: string
        }
        Insert: {
          actor_user_id?: string | null
          attempt_count?: number
          audience_data?: Json
          audience_id?: string | null
          audience_type: string
          batch_count?: number
          body: string
          completed_at?: string | null
          created_at?: string
          event_key: string
          id?: string
          last_error?: string | null
          last_error_code?: string | null
          lease_expires_at?: string | null
          lease_owner?: string | null
          lease_token?: string | null
          localization_args?: Json
          next_attempt_at?: string
          notification_group_key?: string | null
          notification_type: string
          recipient_count?: number
          recipient_cursor?: string | null
          status?: string
          target_id: string
          target_type: string
          title: string
          updated_at?: string
        }
        Update: {
          actor_user_id?: string | null
          attempt_count?: number
          audience_data?: Json
          audience_id?: string | null
          audience_type?: string
          batch_count?: number
          body?: string
          completed_at?: string | null
          created_at?: string
          event_key?: string
          id?: string
          last_error?: string | null
          last_error_code?: string | null
          lease_expires_at?: string | null
          lease_owner?: string | null
          lease_token?: string | null
          localization_args?: Json
          next_attempt_at?: string
          notification_group_key?: string | null
          notification_type?: string
          recipient_count?: number
          recipient_cursor?: string | null
          status?: string
          target_id?: string
          target_type?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      notification_recipients_v2: {
        Row: {
          created_at: string
          notification_id: string
          outbox_id: string
          recipient_id: string
        }
        Insert: {
          created_at?: string
          notification_id: string
          outbox_id: string
          recipient_id: string
        }
        Update: {
          created_at?: string
          notification_id?: string
          outbox_id?: string
          recipient_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_recipients_v2_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_recipients_v2_outbox_id_fkey"
            columns: ["outbox_id"]
            isOneToOne: false
            referencedRelation: "notification_outbox_v2"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          actor_user_id: string | null
          body: string
          created_at: string
          dedupe_key: string
          id: string
          localization_args: Json
          message_count: number
          notification_group_key: string | null
          pipeline_version: number
          push_error: string | null
          push_sent_at: string | null
          push_started_at: string | null
          read_at: string | null
          target_id: string
          target_type: string
          title: string
          type: string
          user_id: string
        }
        Insert: {
          actor_user_id?: string | null
          body: string
          created_at?: string
          dedupe_key: string
          id?: string
          localization_args?: Json
          message_count?: number
          notification_group_key?: string | null
          pipeline_version?: number
          push_error?: string | null
          push_sent_at?: string | null
          push_started_at?: string | null
          read_at?: string | null
          target_id: string
          target_type: string
          title: string
          type: string
          user_id: string
        }
        Update: {
          actor_user_id?: string | null
          body?: string
          created_at?: string
          dedupe_key?: string
          id?: string
          localization_args?: Json
          message_count?: number
          notification_group_key?: string | null
          pipeline_version?: number
          push_error?: string | null
          push_sent_at?: string | null
          push_started_at?: string | null
          read_at?: string | null
          target_id?: string
          target_type?: string
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      pending_password_resets: {
        Row: {
          attempt_count: number
          capability_expires_at: string | null
          capability_hash: string | null
          code_hash: string
          consumed_at: string | null
          created_at: string
          email: string
          expires_at: string
          last_sent_at: string
          max_attempts: number
          verified: boolean
        }
        Insert: {
          attempt_count?: number
          capability_expires_at?: string | null
          capability_hash?: string | null
          code_hash: string
          consumed_at?: string | null
          created_at?: string
          email: string
          expires_at: string
          last_sent_at?: string
          max_attempts?: number
          verified?: boolean
        }
        Update: {
          attempt_count?: number
          capability_expires_at?: string | null
          capability_hash?: string | null
          code_hash?: string
          consumed_at?: string | null
          created_at?: string
          email?: string
          expires_at?: string
          last_sent_at?: string
          max_attempts?: number
          verified?: boolean
        }
        Relationships: []
      }
      pending_signups: {
        Row: {
          attempt_count: number
          capability_expires_at: string | null
          capability_hash: string | null
          code_hash: string
          consumed_at: string | null
          created_at: string
          email: string
          expires_at: string
          last_sent_at: string
          max_attempts: number
          verified: boolean
        }
        Insert: {
          attempt_count?: number
          capability_expires_at?: string | null
          capability_hash?: string | null
          code_hash: string
          consumed_at?: string | null
          created_at?: string
          email: string
          expires_at: string
          last_sent_at?: string
          max_attempts?: number
          verified?: boolean
        }
        Update: {
          attempt_count?: number
          capability_expires_at?: string | null
          capability_hash?: string | null
          code_hash?: string
          consumed_at?: string | null
          created_at?: string
          email?: string
          expires_at?: string
          last_sent_at?: string
          max_attempts?: number
          verified?: boolean
        }
        Relationships: []
      }
      poll_votes: {
        Row: {
          created_at: string
          id: string
          option_index: number
          poll_id: string
          profile_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          option_index: number
          poll_id: string
          profile_id: string
        }
        Update: {
          created_at?: string
          id?: string
          option_index?: number
          poll_id?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "poll_votes_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "poll_votes_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      polls: {
        Row: {
          created_at: string
          id: string
          options: Json
          post_id: string
          question: string
        }
        Insert: {
          created_at?: string
          id?: string
          options: Json
          post_id: string
          question: string
        }
        Update: {
          created_at?: string
          id?: string
          options?: Json
          post_id?: string
          question?: string
        }
        Relationships: [
          {
            foreignKeyName: "polls_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: true
            referencedRelation: "club_posts"
            referencedColumns: ["id"]
          },
        ]
      }
      post_comments: {
        Row: {
          content: string
          created_at: string
          id: string
          parent_comment_id: string | null
          post_id: string
          profile_id: string
        }
        Insert: {
          content: string
          created_at?: string
          id?: string
          parent_comment_id?: string | null
          post_id: string
          profile_id: string
        }
        Update: {
          content?: string
          created_at?: string
          id?: string
          parent_comment_id?: string | null
          post_id?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "post_comments_parent_comment_id_fkey"
            columns: ["parent_comment_id"]
            isOneToOne: false
            referencedRelation: "post_comments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_comments_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      post_likes: {
        Row: {
          created_at: string
          id: string
          post_id: string
          profile_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          post_id: string
          profile_id: string
        }
        Update: {
          created_at?: string
          id?: string
          post_id?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "club_posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_likes_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      post_views: {
        Row: {
          post_id: string
          profile_id: string
          viewed_at: string | null
        }
        Insert: {
          post_id: string
          profile_id: string
          viewed_at?: string | null
        }
        Update: {
          post_id?: string
          profile_id?: string
          viewed_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "post_views_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "club_posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_views_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_double_majors: {
        Row: {
          created_at: string
          id: string
          major_id: string
          profile_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          major_id: string
          profile_id: string
        }
        Update: {
          created_at?: string
          id?: string
          major_id?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_double_majors_major_id_fkey"
            columns: ["major_id"]
            isOneToOne: false
            referencedRelation: "majors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profile_double_majors_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_follows: {
        Row: {
          created_at: string
          follower_id: string
          following_id: string
          id: string
        }
        Insert: {
          created_at?: string
          follower_id: string
          following_id: string
          id?: string
        }
        Update: {
          created_at?: string
          follower_id?: string
          following_id?: string
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_follows_follower_id_fkey"
            columns: ["follower_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profile_follows_following_id_fkey"
            columns: ["following_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_minors: {
        Row: {
          created_at: string
          id: string
          major_id: string
          profile_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          major_id: string
          profile_id: string
        }
        Update: {
          created_at?: string
          id?: string
          major_id?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_minors_major_id_fkey"
            columns: ["major_id"]
            isOneToOne: false
            referencedRelation: "majors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profile_minors_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          academic_year_id: string | null
          avatar_url: string | null
          bio: string | null
          created_at: string
          email: string
          full_name: string
          id: string
          major_id: string | null
          role: string
          tes: boolean | null
          updated_at: string
        }
        Insert: {
          academic_year_id?: string | null
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          email: string
          full_name: string
          id: string
          major_id?: string | null
          role?: string
          tes?: boolean | null
          updated_at?: string
        }
        Update: {
          academic_year_id?: string | null
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          email?: string
          full_name?: string
          id?: string
          major_id?: string | null
          role?: string
          tes?: boolean | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_academic_year_id_fkey"
            columns: ["academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_major_id_fkey"
            columns: ["major_id"]
            isOneToOne: false
            referencedRelation: "majors"
            referencedColumns: ["id"]
          },
        ]
      }
      push_devices: {
        Row: {
          created_at: string
          fcm_token: string
          id: string
          last_seen_at: string
          locale: string
          notifications_enabled: boolean
          platform: string
          user_id: string
        }
        Insert: {
          created_at?: string
          fcm_token: string
          id?: string
          last_seen_at?: string
          locale?: string
          notifications_enabled?: boolean
          platform: string
          user_id: string
        }
        Update: {
          created_at?: string
          fcm_token?: string
          id?: string
          last_seen_at?: string
          locale?: string
          notifications_enabled?: boolean
          platform?: string
          user_id?: string
        }
        Relationships: []
      }
      storage_cleanup_queue_v2: {
        Row: {
          attempt_count: number
          bucket_id: string
          club_id: string
          completed_at: string | null
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          last_error: string | null
          last_error_category: string | null
          lease_expires_at: string | null
          lease_owner: string | null
          lease_token: string | null
          next_attempt_at: string
          object_path: string
          reason: string
          requested_by: string | null
          status: string
          updated_at: string
        }
        Insert: {
          attempt_count?: number
          bucket_id: string
          club_id: string
          completed_at?: string | null
          created_at?: string
          entity_id: string
          entity_type: string
          id?: string
          last_error?: string | null
          last_error_category?: string | null
          lease_expires_at?: string | null
          lease_owner?: string | null
          lease_token?: string | null
          next_attempt_at?: string
          object_path: string
          reason: string
          requested_by?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          attempt_count?: number
          bucket_id?: string
          club_id?: string
          completed_at?: string | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: string
          last_error?: string | null
          last_error_category?: string | null
          lease_expires_at?: string | null
          lease_owner?: string | null
          lease_token?: string | null
          next_attempt_at?: string
          object_path?: string
          reason?: string
          requested_by?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "storage_cleanup_queue_v2_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      student_interests: {
        Row: {
          created_at: string
          interest_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          interest_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          interest_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_interests_interest_id_fkey"
            columns: ["interest_id"]
            isOneToOne: false
            referencedRelation: "interests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_interests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      terms_acceptances: {
        Row: {
          accepted_at: string
          terms_version: string
          user_id: string
        }
        Insert: {
          accepted_at?: string
          terms_version: string
          user_id: string
        }
        Update: {
          accepted_at?: string
          terms_version?: string
          user_id?: string
        }
        Relationships: []
      }
      user_blocks: {
        Row: {
          blocked_id: string
          blocker_id: string
          created_at: string
        }
        Insert: {
          blocked_id: string
          blocker_id: string
          created_at?: string
        }
        Update: {
          blocked_id?: string
          blocker_id?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_preferences: {
        Row: {
          created_at: string
          has_completed_tutorial: boolean
          language_code: string | null
          onboarding_version: number | null
          theme_mode: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          has_completed_tutorial?: boolean
          language_code?: string | null
          onboarding_version?: number | null
          theme_mode?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          has_completed_tutorial?: boolean
          language_code?: string | null
          onboarding_version?: number | null
          theme_mode?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_presence_status: {
        Row: {
          last_seen_at: string
          user_id: string
        }
        Insert: {
          last_seen_at?: string
          user_id: string
        }
        Update: {
          last_seen_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_presence_status_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      club_member_counts: {
        Row: {
          club_id: string | null
          member_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "club_followers_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      event_rsvp_counts: {
        Row: {
          event_id: string | null
          rsvp_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "event_rsvps_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      post_like_counts: {
        Row: {
          like_count: number | null
          post_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "club_posts"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      cancel_password_reset_challenge_v2: {
        Args: { p_code_hash: string; p_email: string }
        Returns: undefined
      }
      cancel_signup_challenge_v2: {
        Args: { p_code_hash: string; p_email: string }
        Returns: undefined
      }
      check_in_event_v2: {
        Args: { p_event_id: string; p_method?: string; p_profile_id: string }
        Returns: {
          checked_in_at: string
          checked_in_by: string | null
          event_id: string
          id: string
          legacy_checked_in_by: string | null
          method: string
          profile_id: string
        }
        SetofOptions: {
          from: "*"
          to: "event_checkins"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      claim_notification_deliveries_v2: {
        Args: {
          p_batch_size?: number
          p_lease_seconds?: number
          p_max_attempts?: number
          p_worker: string
        }
        Returns: {
          actor_user_id: string
          attempt_count: number
          body: string
          delivery_id: string
          device_id: string
          fcm_token: string
          lease_token: string
          locale: string
          localization_args: Json
          message_count: number
          notification_group_key: string
          notification_id: string
          notification_type: string
          target_id: string
          target_type: string
          title: string
        }[]
      }
      claim_notification_outbox_v2: {
        Args: {
          p_lease_seconds?: number
          p_max_attempts?: number
          p_worker: string
        }
        Returns: Json
      }
      claim_storage_cleanup_v2: {
        Args: { p_lease_seconds?: number; p_limit?: number; p_worker: string }
        Returns: {
          attempt_count: number
          bucket_id: string
          club_id: string
          completed_at: string | null
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          last_error: string | null
          last_error_category: string | null
          lease_expires_at: string | null
          lease_owner: string | null
          lease_token: string | null
          next_attempt_at: string
          object_path: string
          reason: string
          requested_by: string | null
          status: string
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "storage_cleanup_queue_v2"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      cleanup_expired_events: { Args: never; Returns: number }
      complete_notification_delivery_v2: {
        Args: {
          p_delivery_id: string
          p_error?: string
          p_error_code?: string
          p_http_status?: number
          p_lease_token: string
          p_max_attempts?: number
          p_outcome: string
          p_provider_message_id?: string
        }
        Returns: undefined
      }
      complete_storage_cleanup_v2: {
        Args: { p_cleanup_id: string }
        Returns: boolean
      }
      complete_storage_cleanup_worker_v2: {
        Args: {
          p_cleanup_id: string
          p_error?: string
          p_error_category?: string
          p_lease_token: string
          p_outcome: string
        }
        Returns: boolean
      }
      consume_edge_rate_limit: {
        Args: { p_action: string; p_scope: string }
        Returns: {
          allowed: boolean
          limiting_window: string
          retry_after_seconds: number
        }[]
      }
      consume_password_reset_capability: {
        Args: { p_capability_hash: string; p_email: string }
        Returns: string
      }
      consume_password_reset_capability_v2: {
        Args: { p_capability_hash: string; p_email: string }
        Returns: string
      }
      consume_password_reset_verification_legacy: {
        Args: { p_email: string }
        Returns: string
      }
      consume_signup_capability: {
        Args: { p_capability_hash: string; p_email: string }
        Returns: string
      }
      consume_signup_capability_v2: {
        Args: { p_capability_hash: string; p_email: string }
        Returns: string
      }
      consume_signup_verification_legacy: {
        Args: { p_email: string }
        Returns: string
      }
      create_club_event_transactional_v2: {
        Args: {
          p_club_id: string
          p_description: string
          p_ends_at: string
          p_event_date: string
          p_event_id: string
          p_image_path?: string
          p_image_url?: string
          p_location: string
          p_registration_url?: string
          p_schedule?: Json
          p_speakers?: Json
          p_starts_at: string
          p_tags?: string[]
          p_title: string
        }
        Returns: {
          club_id: string
          created_at: string
          created_by_user_id: string | null
          description: string | null
          ends_at: string | null
          event_date: string
          id: string
          image_path: string | null
          image_url: string | null
          is_public: boolean
          location: string | null
          registration_url: string | null
          schedule: Json | null
          speakers: Json | null
          starts_at: string
          tags: string[]
          title: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "events"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_club_event_v2: {
        Args: {
          p_club_id: string
          p_created_by_user_id: string
          p_description: string
          p_ends_at: string
          p_event_date: string
          p_image_path?: string
          p_image_url?: string
          p_location: string
          p_registration_url?: string
          p_schedule?: Json
          p_speakers?: Json
          p_starts_at: string
          p_tags?: string[]
          p_title: string
        }
        Returns: {
          club_id: string
          created_at: string
          created_by_user_id: string | null
          description: string | null
          ends_at: string | null
          event_date: string
          id: string
          image_path: string | null
          image_url: string | null
          is_public: boolean
          location: string | null
          registration_url: string | null
          schedule: Json | null
          speakers: Json | null
          starts_at: string
          tags: string[]
          title: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "events"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_club_post_transactional_v2: {
        Args: {
          p_club_id: string
          p_content: string
          p_image_path?: string
          p_image_url?: string
          p_is_announcement?: boolean
          p_mentioned_user_ids?: string[]
          p_poll_options?: Json
          p_poll_question?: string
          p_post_id: string
        }
        Returns: {
          author_id: string | null
          club_id: string
          content: string
          created_at: string
          id: string
          image_path: string | null
          image_url: string | null
          is_announcement: boolean
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "club_posts"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_club_post_v2: {
        Args: {
          p_author_id?: string
          p_club_id: string
          p_content: string
          p_image_path?: string
          p_image_url?: string
          p_is_announcement?: boolean
          p_mentioned_user_ids?: string[]
        }
        Returns: {
          author_id: string | null
          club_id: string
          content: string
          created_at: string
          id: string
          image_path: string | null
          image_url: string | null
          is_announcement: boolean
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "club_posts"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_poll_v2: {
        Args: { p_options: Json; p_post_id: string; p_question: string }
        Returns: {
          created_at: string
          id: string
          options: Json
          post_id: string
          question: string
        }
        SetofOptions: {
          from: "*"
          to: "polls"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      delete_club_event_transactional_v2: {
        Args: { p_club_id: string; p_event_id: string }
        Returns: Json
      }
      delete_club_post_transactional_v2: {
        Args: { p_club_id: string; p_post_id: string }
        Returns: Json
      }
      expand_notification_outbox_v2: {
        Args: {
          p_batch_size?: number
          p_lease_token: string
          p_outbox_id: string
        }
        Returns: Json
      }
      fail_notification_outbox_v2: {
        Args: {
          p_error: string
          p_error_code: string
          p_lease_token: string
          p_max_attempts?: number
          p_outbox_id: string
          p_retryable?: boolean
        }
        Returns: undefined
      }
      get_conversation_summaries_v2: {
        Args: {
          p_cursor_activity_at?: string
          p_cursor_thread_id?: string
          p_limit?: number
        }
        Returns: Json
      }
      get_feed_page_v2: {
        Args: {
          p_cursor_created_at?: string
          p_cursor_id?: string
          p_followed_only?: boolean
          p_limit?: number
        }
        Returns: Json
      }
      get_messages_page_v2: {
        Args: {
          p_cursor_created_at?: string
          p_cursor_id?: string
          p_limit?: number
          p_thread_id: string
        }
        Returns: Json
      }
      get_messages_since_v2: {
        Args: {
          p_after_change_id: number
          p_limit?: number
          p_thread_id: string
        }
        Returns: Json
      }
      get_private_profile_email: {
        Args: { p_profile_id: string }
        Returns: string
      }
      get_private_profile_emails: {
        Args: { p_profile_ids: string[] }
        Returns: {
          email: string
          profile_id: string
        }[]
      }
      is_club_auth_account_for: {
        Args: { target_club_id: string }
        Returns: boolean
      }
      issue_password_reset_challenge: {
        Args: { p_code_hash: string; p_email: string; p_expires_at: string }
        Returns: string
      }
      issue_password_reset_challenge_legacy: {
        Args: { p_code_hash: string; p_email: string; p_expires_at: string }
        Returns: string
      }
      issue_password_reset_challenge_v2: {
        Args: { p_code_hash: string; p_email: string; p_expires_at: string }
        Returns: string
      }
      issue_signup_challenge: {
        Args: { p_code_hash: string; p_email: string; p_expires_at: string }
        Returns: string
      }
      issue_signup_challenge_legacy: {
        Args: { p_code_hash: string; p_email: string; p_expires_at: string }
        Returns: string
      }
      issue_signup_challenge_v2: {
        Args: { p_code_hash: string; p_email: string; p_expires_at: string }
        Returns: string
      }
      mark_conversation_read_v2: {
        Args: {
          p_scope?: string
          p_thread_id: string
          p_through_created_at: string
          p_through_message_id: string
        }
        Returns: Json
      }
      notification_v2_metrics: { Args: never; Returns: Json }
      record_terms_acceptance: {
        Args: { p_terms_version: string }
        Returns: string
      }
      register_abandoned_content_upload_v2: {
        Args: {
          p_bucket_id: string
          p_club_id: string
          p_entity_id: string
          p_entity_type: string
          p_object_path: string
        }
        Returns: string
      }
      remove_event_checkin_v2: {
        Args: { p_event_id: string; p_profile_id: string }
        Returns: boolean
      }
      remove_poll_vote_v2: { Args: { p_poll_id: string }; Returns: boolean }
      restrict_signup_to_ku: { Args: { event: Json }; Returns: Json }
      revoke_user_sessions: { Args: { p_user_id: string }; Returns: number }
      send_message_v2: {
        Args: {
          p_content: string
          p_created_at?: string
          p_message_id: string
          p_message_kind?: string
          p_payload?: Json
          p_send_as_club?: boolean
          p_thread_id: string
        }
        Returns: Json
      }
      storage_cleanup_is_referenced_v2: {
        Args: { p_cleanup_id: string; p_lease_token: string }
        Returns: boolean
      }
      update_club_event_transactional_v2: {
        Args: {
          p_description: string
          p_ends_at: string
          p_event_date: string
          p_event_id: string
          p_image_path: string
          p_image_url: string
          p_location: string
          p_registration_url: string
          p_schedule: Json
          p_speakers: Json
          p_starts_at: string
          p_tags: string[]
          p_title: string
        }
        Returns: Json
      }
      update_profile_v2: {
        Args: {
          p_academic_year_id: string
          p_bio: string
          p_double_major_ids?: string[]
          p_full_name: string
          p_interest_ids?: string[]
          p_major_id: string
          p_minor_ids?: string[]
        }
        Returns: Json
      }
      verify_password_reset_challenge: {
        Args: {
          p_capability_hash: string
          p_code_hash: string
          p_email: string
        }
        Returns: string
      }
      verify_password_reset_challenge_legacy: {
        Args: { p_code_hash: string; p_email: string }
        Returns: string
      }
      verify_password_reset_challenge_v2: {
        Args: {
          p_capability_hash: string
          p_code_hash: string
          p_email: string
        }
        Returns: string
      }
      verify_signup_challenge: {
        Args: {
          p_capability_hash: string
          p_code_hash: string
          p_email: string
        }
        Returns: string
      }
      verify_signup_challenge_legacy: {
        Args: { p_code_hash: string; p_email: string }
        Returns: string
      }
      verify_signup_challenge_v2: {
        Args: {
          p_capability_hash: string
          p_code_hash: string
          p_email: string
        }
        Returns: string
      }
      vote_poll_v2: {
        Args: { p_option_index: number; p_poll_id: string }
        Returns: {
          created_at: string
          id: string
          option_index: number
          poll_id: string
          profile_id: string
        }
        SetofOptions: {
          from: "*"
          to: "poll_votes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const
