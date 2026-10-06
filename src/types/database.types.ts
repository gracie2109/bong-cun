export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      banners: {
        Row: {
          created_at: string
          id: string
          image_url: string | null
          is_active: boolean
          link_url: string | null
          sort_order: number
          title: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          link_url?: string | null
          sort_order?: number
          title?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          link_url?: string | null
          sort_order?: number
          title?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      bookings: {
        Row: {
          cancel_by: string | null
          cancel_date: string | null
          cancel_reason: string | null
          confirm_changed_by: string | null
          confirm_from_time: string | null
          confirm_to_time: string | null
          content: string | null
          created_at: string
          email: string
          id: string
          is_cancel: boolean
          is_moving_time: boolean
          name: string
          phone_number: string
          scheduled_at: string
          status: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          cancel_by?: string | null
          cancel_date?: string | null
          cancel_reason?: string | null
          confirm_changed_by?: string | null
          confirm_from_time?: string | null
          confirm_to_time?: string | null
          content?: string | null
          created_at?: string
          email: string
          id?: string
          is_cancel?: boolean
          is_moving_time?: boolean
          name: string
          phone_number: string
          scheduled_at: string
          status?: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          cancel_by?: string | null
          cancel_date?: string | null
          cancel_reason?: string | null
          confirm_changed_by?: string | null
          confirm_from_time?: string | null
          confirm_to_time?: string | null
          content?: string | null
          created_at?: string
          email?: string
          id?: string
          is_cancel?: boolean
          is_moving_time?: boolean
          name?: string
          phone_number?: string
          scheduled_at?: string
          status?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      combo_pets: {
        Row: {
          combo_id: string
          pet_id: string
        }
        Insert: {
          combo_id: string
          pet_id: string
        }
        Update: {
          combo_id?: string
          pet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "combo_pets_combo_id_fkey"
            columns: ["combo_id"]
            isOneToOne: false
            referencedRelation: "pet_service_combos"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "combo_pets_pet_id_fkey"
            columns: ["pet_id"]
            isOneToOne: false
            referencedRelation: "pets"
            referencedColumns: ["id"]
          },
        ]
      }
      combo_services: {
        Row: {
          combo_id: string
          service_id: string
        }
        Insert: {
          combo_id: string
          service_id: string
        }
        Update: {
          combo_id?: string
          service_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "combo_services_combo_id_fkey"
            columns: ["combo_id"]
            isOneToOne: false
            referencedRelation: "pet_service_combos"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "combo_services_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "pet_services"
            referencedColumns: ["id"]
          },
        ]
      }
      order_items: {
        Row: {
          cancel_by: string | null
          cancel_date: string | null
          cancel_reason: string | null
          changes_by: string | null
          changes_from_time: string | null
          changes_to_time: string | null
          combo_id: string | null
          created_at: string
          duration_minutes: number | null
          id: string
          is_cancel: boolean
          is_moving_time: boolean
          name: string
          order_id: string
          price: number
          service_id: string | null
          status: string
          updated_at: string
        }
        Insert: {
          cancel_by?: string | null
          cancel_date?: string | null
          cancel_reason?: string | null
          changes_by?: string | null
          changes_from_time?: string | null
          changes_to_time?: string | null
          combo_id?: string | null
          created_at?: string
          duration_minutes?: number | null
          id?: string
          is_cancel?: boolean
          is_moving_time?: boolean
          name: string
          order_id: string
          price: number
          service_id?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          cancel_by?: string | null
          cancel_date?: string | null
          cancel_reason?: string | null
          changes_by?: string | null
          changes_from_time?: string | null
          changes_to_time?: string | null
          combo_id?: string | null
          created_at?: string
          duration_minutes?: number | null
          id?: string
          is_cancel?: boolean
          is_moving_time?: boolean
          name?: string
          order_id?: string
          price?: number
          service_id?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_items_combo_id_fkey"
            columns: ["combo_id"]
            isOneToOne: false
            referencedRelation: "pet_service_combos"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "pet_services"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          created_at: string
          id: string
          name: string
          pet_num: number | null
          phone_number: string
          scheduled_at: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          pet_num?: number | null
          phone_number: string
          scheduled_at?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          pet_num?: number | null
          phone_number?: string
          scheduled_at?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      permissions: {
        Row: {
          created_at: string
          description: string | null
          methods: string[]
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          methods?: string[]
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          methods?: string[]
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      pet_service_combos: {
        Row: {
          created_at: string
          description: string | null
          duration_minutes: number | null
          id: string
          mark_as_id: string | null
          mark_end: string | null
          mark_start: string | null
          name: string
          origin_price: number | null
          price: number | null
          status: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          duration_minutes?: number | null
          id?: string
          mark_as_id?: string | null
          mark_end?: string | null
          mark_start?: string | null
          name: string
          origin_price?: number | null
          price?: number | null
          status?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          duration_minutes?: number | null
          id?: string
          mark_as_id?: string | null
          mark_end?: string | null
          mark_start?: string | null
          name?: string
          origin_price?: number | null
          price?: number | null
          status?: number
          updated_at?: string
        }
        Relationships: []
      }
      pet_service_pets: {
        Row: {
          pet_id: string
          service_id: string
        }
        Insert: {
          pet_id: string
          service_id: string
        }
        Update: {
          pet_id?: string
          service_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "pet_service_pets_pet_id_fkey"
            columns: ["pet_id"]
            isOneToOne: false
            referencedRelation: "pets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pet_service_pets_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "pet_services"
            referencedColumns: ["id"]
          },
        ]
      }
      pet_service_prices: {
        Row: {
          created_at: string
          id: string
          pet_id: string
          price: number
          service_id: string
          updated_at: string
          weight_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          pet_id: string
          price: number
          service_id: string
          updated_at?: string
          weight_id: string
        }
        Update: {
          created_at?: string
          id?: string
          pet_id?: string
          price?: number
          service_id?: string
          updated_at?: string
          weight_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "pet_service_prices_pet_id_fkey"
            columns: ["pet_id"]
            isOneToOne: false
            referencedRelation: "pets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pet_service_prices_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "pet_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pet_service_prices_weight_id_fkey"
            columns: ["weight_id"]
            isOneToOne: false
            referencedRelation: "pet_weights"
            referencedColumns: ["id"]
          },
        ]
      }
      pet_services: {
        Row: {
          created_at: string
          description: string | null
          duration_minutes: number | null
          general_price: number | null
          id: string
          is_show: boolean
          name: string
          type: string | null
          unit: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          duration_minutes?: number | null
          general_price?: number | null
          id?: string
          is_show?: boolean
          name: string
          type?: string | null
          unit?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          duration_minutes?: number | null
          general_price?: number | null
          id?: string
          is_show?: boolean
          name?: string
          type?: string | null
          unit?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      pet_weights: {
        Row: {
          id: string
          label_en: string
          label_vi: string
          sort_order: number
        }
        Insert: {
          id: string
          label_en: string
          label_vi: string
          sort_order?: number
        }
        Update: {
          id?: string
          label_en?: string
          label_vi?: string
          sort_order?: number
        }
        Relationships: []
      }
      pets: {
        Row: {
          created_at: string
          description: string | null
          icon: string | null
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      products: {
        Row: {
          created_at: string
          description: string | null
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      users: {
        Row: {
          address: Json | null
          created_at: string
          display_name: string | null
          email: string | null
          full_name: string | null
          gender: string | null
          id: string
          phone_number: string | null
          photo_url: string | null
          role: string
          updated_at: string
        }
        Insert: {
          address?: Json | null
          created_at?: string
          display_name?: string | null
          email?: string | null
          full_name?: string | null
          gender?: string | null
          id: string
          phone_number?: string | null
          photo_url?: string | null
          role?: string
          updated_at?: string
        }
        Update: {
          address?: Json | null
          created_at?: string
          display_name?: string | null
          email?: string | null
          full_name?: string | null
          gender?: string | null
          id?: string
          phone_number?: string | null
          photo_url?: string | null
          role?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "users_role_fkey"
            columns: ["role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["name"]
          },
        ]
      }
      role_permissions: {
        Row: {
          methods: string[]
          permission: string
          role: string
        }
        Insert: {
          methods?: string[]
          permission: string
          role: string
        }
        Update: {
          methods?: string[]
          permission?: string
          role?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_fkey"
            columns: ["permission"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["name"]
          },
          {
            foreignKeyName: "role_permissions_role_fkey"
            columns: ["role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["name"]
          },
        ]
      }
      roles: {
        Row: {
          created_at: string
          description: string | null
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      service_providers: {
        Row: {
          created_at: string
          description: string | null
          id: string
          name: string
          phone: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          name: string
          phone?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          name?: string
          phone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      create_order: { Args: { p: Json }; Returns: string }
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      is_admin: { Args: never; Returns: boolean }
      is_display_name_available: {
        Args: { p_display_name: string }
        Returns: boolean
      }
      is_super_admin: { Args: never; Returns: boolean }
      save_pet_combo: { Args: { p: Json; p_id?: string }; Returns: string }
      save_pet_service: { Args: { p: Json; p_id?: string }; Returns: string }
      save_role: { Args: { p: Json; p_id?: string }; Returns: string }
      save_service_prices: {
        Args: { p_pet_id: string; p_rows: Json; p_service_id: string }
        Returns: undefined
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
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
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
