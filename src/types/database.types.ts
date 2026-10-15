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
      branches: {
        Row: {
          address: string | null
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          phone: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          phone?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          phone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      cash_shifts: {
        Row: {
          branch_id: string
          close_note: string | null
          closed_at: string | null
          closed_by: string | null
          closed_by_name: string | null
          code: string
          counted_cash: number | null
          created_at: string
          expected_cash: number | null
          id: string
          open_note: string | null
          opened_at: string
          opened_by: string
          opened_by_name: string | null
          opening_cash: number
          status: string
          updated_at: string
        }
        Insert: {
          branch_id: string
          close_note?: string | null
          closed_at?: string | null
          closed_by?: string | null
          closed_by_name?: string | null
          code: string
          counted_cash?: number | null
          created_at?: string
          expected_cash?: number | null
          id?: string
          open_note?: string | null
          opened_at?: string
          opened_by: string
          opened_by_name?: string | null
          opening_cash: number
          status?: string
          updated_at?: string
        }
        Update: {
          branch_id?: string
          close_note?: string | null
          closed_at?: string | null
          closed_by?: string | null
          closed_by_name?: string | null
          code?: string
          counted_cash?: number | null
          created_at?: string
          expected_cash?: number | null
          id?: string
          open_note?: string | null
          opened_at?: string
          opened_by?: string
          opened_by_name?: string | null
          opening_cash?: number
          status?: string
          updated_at?: string
        }
        Relationships: []
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
      combo_species: {
        Row: {
          combo_id: string
          species_id: string
        }
        Insert: {
          combo_id: string
          species_id: string
        }
        Update: {
          combo_id?: string
          species_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "combo_species_combo_id_fkey"
            columns: ["combo_id"]
            isOneToOne: false
            referencedRelation: "pet_service_combos"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "combo_species_species_id_fkey"
            columns: ["species_id"]
            isOneToOne: false
            referencedRelation: "species"
            referencedColumns: ["id"]
          },
        ]
      }
      customers: {
        Row: {
          created_at: string
          created_by: string | null
          email: string | null
          full_name: string
          id: string
          is_active: boolean
          note: string | null
          phone: string
          phone_digits: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          email?: string | null
          full_name: string
          id?: string
          is_active?: boolean
          note?: string | null
          phone: string
          phone_digits?: never
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          email?: string | null
          full_name?: string
          id?: string
          is_active?: boolean
          note?: string | null
          phone?: string
          phone_digits?: never
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customers_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      invoices: {
        Row: {
          branch_id: string
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          cashier_name: string | null
          change_amount: number
          channel: string
          client_ref: string | null
          code: string
          created_at: string
          created_by: string
          customer_id: string | null
          customer_name: string | null
          customer_phone: string | null
          discount_amount: number
          einvoice_no: string | null
          id: string
          note: string | null
          paid_amount: number
          shift_id: string | null
          status: string
          subtotal: number
          total: number
          updated_at: string
        }
        Insert: {
          branch_id: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cashier_name?: string | null
          change_amount?: number
          channel?: string
          client_ref?: string | null
          code: string
          created_at?: string
          created_by: string
          customer_id?: string | null
          customer_name?: string | null
          customer_phone?: string | null
          discount_amount?: number
          einvoice_no?: string | null
          id?: string
          note?: string | null
          paid_amount?: number
          shift_id?: string | null
          status?: string
          subtotal: number
          total: number
          updated_at?: string
        }
        Update: {
          branch_id?: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cashier_name?: string | null
          change_amount?: number
          channel?: string
          client_ref?: string | null
          code?: string
          created_at?: string
          created_by?: string
          customer_id?: string | null
          customer_name?: string | null
          customer_phone?: string | null
          discount_amount?: number
          einvoice_no?: string | null
          id?: string
          note?: string | null
          paid_amount?: number
          shift_id?: string | null
          status?: string
          subtotal?: number
          total?: number
          updated_at?: string
        }
        Relationships: []
      }
      invoice_lines: {
        Row: {
          cost_amount: number | null
          amount: number
          combo_id: string | null
          id: string
          invoice_id: string
          item_type: string
          line_no: number
          name: string
          pet_id: string | null
          pet_name: string | null
          product_id: string | null
          qty: number
          service_id: string | null
          unit: string | null
          unit_price: number
          weight_kg: number | null
          base_qty: number | null
          unit_factor: number
          unit_id: string | null
        }
        Insert: {
          cost_amount?: number | null
          amount: number
          combo_id?: string | null
          id?: string
          invoice_id: string
          item_type: string
          line_no: number
          name: string
          pet_id?: string | null
          pet_name?: string | null
          product_id?: string | null
          qty: number
          service_id?: string | null
          unit?: string | null
          unit_price: number
          weight_kg?: number | null
          unit_factor?: number
          unit_id?: string | null
        }
        Update: {
          cost_amount?: number | null
          amount?: number
          combo_id?: string | null
          id?: string
          invoice_id?: string
          item_type?: string
          line_no?: number
          name?: string
          pet_id?: string | null
          pet_name?: string | null
          product_id?: string | null
          qty?: number
          service_id?: string | null
          unit?: string | null
          unit_price?: number
          weight_kg?: number | null
          unit_factor?: number
          unit_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "invoice_lines_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
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
      payments: {
        Row: {
          amount: number
          bank_ref: string | null
          created_at: string
          id: string
          invoice_id: string
          method: string
        }
        Insert: {
          amount: number
          bank_ref?: string | null
          created_at?: string
          id?: string
          invoice_id: string
          method: string
        }
        Update: {
          amount?: number
          bank_ref?: string | null
          created_at?: string
          id?: string
          invoice_id?: string
          method?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          created_at: string
          description: string | null
          methods: string[]
          module: string | null
          name: string
          sort_order: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          methods?: string[]
          module?: string | null
          name: string
          sort_order?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          methods?: string[]
          module?: string | null
          name?: string
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      pet_owners: {
        Row: {
          customer_id: string
          from_date: string
          pet_id: string
          role: string
          to_date: string | null
        }
        Insert: {
          customer_id: string
          from_date?: string
          pet_id: string
          role?: string
          to_date?: string | null
        }
        Update: {
          customer_id?: string
          from_date?: string
          pet_id?: string
          role?: string
          to_date?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "pet_owners_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pet_owners_pet_id_fkey"
            columns: ["pet_id"]
            isOneToOne: false
            referencedRelation: "pets"
            referencedColumns: ["id"]
          },
        ]
      }
      pet_service_combos: {
        Row: {
          created_at: string
          description: string | null
          duration_minutes: number | null
          id: string
          is_active: boolean
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
          is_active?: boolean
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
          is_active?: boolean
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
      pet_service_prices: {
        Row: {
          bracket_id: string
          branch_id: string | null
          created_at: string
          id: string
          price: number
          service_id: string
          species_id: string
          updated_at: string
        }
        Insert: {
          bracket_id: string
          branch_id?: string | null
          created_at?: string
          id?: string
          price: number
          service_id: string
          species_id: string
          updated_at?: string
        }
        Update: {
          bracket_id?: string
          branch_id?: string | null
          created_at?: string
          id?: string
          price?: number
          service_id?: string
          species_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "pet_service_prices_bracket_id_fkey"
            columns: ["bracket_id"]
            isOneToOne: false
            referencedRelation: "weight_brackets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pet_service_prices_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
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
            foreignKeyName: "pet_service_prices_species_id_fkey"
            columns: ["species_id"]
            isOneToOne: false
            referencedRelation: "species"
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
          is_active: boolean
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
          is_active?: boolean
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
          is_active?: boolean
          is_show?: boolean
          name?: string
          type?: string | null
          unit?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      pet_weight_logs: {
        Row: {
          created_by: string | null
          id: string
          measured_at: string
          note: string | null
          pet_id: string
          weight_kg: number
        }
        Insert: {
          created_by?: string | null
          id?: string
          measured_at?: string
          note?: string | null
          pet_id: string
          weight_kg: number
        }
        Update: {
          created_by?: string | null
          id?: string
          measured_at?: string
          note?: string | null
          pet_id?: string
          weight_kg?: number
        }
        Relationships: [
          {
            foreignKeyName: "pet_weight_logs_pet_id_fkey"
            columns: ["pet_id"]
            isOneToOne: false
            referencedRelation: "pets"
            referencedColumns: ["id"]
          },
        ]
      }
      pets: {
        Row: {
          allergies: string | null
          behavior_notes: string | null
          birth_date: string | null
          breed: string | null
          created_at: string
          created_by: string | null
          id: string
          microchip: string | null
          name: string
          neutered: boolean
          photo_url: string | null
          sex: string
          species_id: string
          status: string
          updated_at: string
        }
        Insert: {
          allergies?: string | null
          behavior_notes?: string | null
          birth_date?: string | null
          breed?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          microchip?: string | null
          name: string
          neutered?: boolean
          photo_url?: string | null
          sex?: string
          species_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          allergies?: string | null
          behavior_notes?: string | null
          birth_date?: string | null
          breed?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          microchip?: string | null
          name?: string
          neutered?: boolean
          photo_url?: string | null
          sex?: string
          species_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "pets_species_id_fkey"
            columns: ["species_id"]
            isOneToOne: false
            referencedRelation: "species"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_settings: {
        Row: {
          id: boolean
          online_branch_id: string
          allow_cod: boolean
          allow_pickup: boolean
          cod_max: number
          default_weight_g: number
          flat_shipping_fee: number
          free_ship_from: number | null
          ghn_from_province_id: number | null
          ghn_from_district_id: number | null
          ghn_from_ward_code: string | null
          from_address_text: string | null
          pickup_address: string | null
          pickup_note: string | null
          updated_at: string
        }
        Insert: {
          id?: boolean
          online_branch_id: string
          allow_cod?: boolean
          allow_pickup?: boolean
          cod_max?: number
          default_weight_g?: number
          flat_shipping_fee?: number
          free_ship_from?: number | null
          ghn_from_province_id?: number | null
          ghn_from_district_id?: number | null
          ghn_from_ward_code?: string | null
          from_address_text?: string | null
          pickup_address?: string | null
          pickup_note?: string | null
          updated_at?: string
        }
        Update: {
          id?: boolean
          online_branch_id?: string
          allow_cod?: boolean
          allow_pickup?: boolean
          cod_max?: number
          default_weight_g?: number
          flat_shipping_fee?: number
          free_ship_from?: number | null
          ghn_from_province_id?: number | null
          ghn_from_district_id?: number | null
          ghn_from_ward_code?: string | null
          from_address_text?: string | null
          pickup_address?: string | null
          pickup_note?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      products: {
        Row: {
          track_stock: boolean
          barcode: string | null
          created_at: string
          description: string | null
          group_id: string
          id: string
          image_url: string | null
          is_active: boolean
          name: string
          option_key: string
          price: number
          sku: string | null
          sort_order: number
          unit: string
          updated_at: string
          weight_g: number | null
          ship_policy: string
        }
        Insert: {
          track_stock?: boolean
          barcode?: string | null
          created_at?: string
          description?: string | null
          group_id: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name: string
          option_key?: string
          price?: number
          sku?: string | null
          sort_order?: number
          unit?: string
          updated_at?: string
          weight_g?: number | null
          ship_policy?: string
        }
        Update: {
          track_stock?: boolean
          barcode?: string | null
          created_at?: string
          description?: string | null
          group_id?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name?: string
          option_key?: string
          price?: number
          sku?: string | null
          sort_order?: number
          unit?: string
          updated_at?: string
          weight_g?: number | null
          ship_policy?: string
        }
        Relationships: [
          {
            foreignKeyName: "products_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "product_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      product_attributes: {
        Row: { created_at: string; id: string; name: string }
        Insert: { created_at?: string; id?: string; name: string }
        Update: { created_at?: string; id?: string; name?: string }
        Relationships: []
      }
      product_attribute_values: {
        Row: { attribute_id: string; created_at: string; id: string; sort_order: number; value: string }
        Insert: { attribute_id: string; created_at?: string; id?: string; sort_order?: number; value: string }
        Update: { attribute_id?: string; created_at?: string; id?: string; sort_order?: number; value?: string }
        Relationships: [
          {
            foreignKeyName: "product_attribute_values_attribute_id_fkey"
            columns: ["attribute_id"]
            isOneToOne: false
            referencedRelation: "product_attributes"
            referencedColumns: ["id"]
          },
        ]
      }
      product_groups: {
        Row: {
          brand_id: string | null
          category_id: string | null
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          image_url: string | null
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          brand_id?: string | null
          category_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          brand_id?: string | null
          category_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_groups_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "product_brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_groups_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["id"]
          },
        ]
      }
      product_imports: {
        Row: {
          created_at: string
          created_by: string | null
          created_count: number
          file_name: string | null
          id: string
          row_count: number
          updated_count: number
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          created_count?: number
          file_name?: string | null
          id?: string
          row_count?: number
          updated_count?: number
        }
        Update: {
          created_at?: string
          created_by?: string | null
          created_count?: number
          file_name?: string | null
          id?: string
          row_count?: number
          updated_count?: number
        }
        Relationships: []
      }
      product_branch_prices: {
        Row: {
          branch_id: string
          price: number
          product_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          branch_id: string
          price: number
          product_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          branch_id?: string
          price?: number
          product_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_branch_prices_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_branch_prices_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_units: {
        Row: {
          barcode: string | null
          created_at: string
          factor: number
          for_purchase: boolean
          for_sale: boolean
          id: string
          is_active: boolean
          name: string
          price: number | null
          product_id: string
          sort_order: number
        }
        Insert: {
          barcode?: string | null
          created_at?: string
          factor: number
          for_purchase?: boolean
          for_sale?: boolean
          id?: string
          is_active?: boolean
          name: string
          price?: number | null
          product_id: string
          sort_order?: number
        }
        Update: {
          barcode?: string | null
          created_at?: string
          factor?: number
          for_purchase?: boolean
          for_sale?: boolean
          id?: string
          is_active?: boolean
          name?: string
          price?: number | null
          product_id?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "product_units_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_brands: {
        Row: {
          created_at: string
          id: string
          image_url: string | null
          is_active: boolean
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      product_categories: {
        Row: {
          created_at: string
          id: string
          image_url: string | null
          is_active: boolean
          name: string
          parent_id: string | null
          slug: string
          sort_order: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name: string
          parent_id?: string | null
          slug: string
          sort_order?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name?: string
          parent_id?: string | null
          slug?: string
          sort_order?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_categories_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["id"]
          },
        ]
      }
      product_group_attributes: {
        Row: { attribute_id: string; group_id: string; sort_order: number }
        Insert: { attribute_id: string; group_id: string; sort_order?: number }
        Update: { attribute_id?: string; group_id?: string; sort_order?: number }
        Relationships: [
          {
            foreignKeyName: "product_group_attributes_attribute_id_fkey"
            columns: ["attribute_id"]
            isOneToOne: false
            referencedRelation: "product_attributes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_group_attributes_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "product_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      product_variant_values: {
        Row: { attribute_id: string; product_id: string; value_id: string }
        Insert: { attribute_id: string; product_id: string; value_id: string }
        Update: { attribute_id?: string; product_id?: string; value_id?: string }
        Relationships: [
          {
            foreignKeyName: "product_variant_values_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_variant_values_value_id_fkey"
            columns: ["value_id"]
            isOneToOne: false
            referencedRelation: "product_attribute_values"
            referencedColumns: ["id"]
          },
        ]
      }
      suppliers: {
        Row: {
          address: string | null
          created_at: string
          email: string | null
          id: string
          is_active: boolean
          name: string
          note: string | null
          phone: string | null
          tax_code: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          email?: string | null
          id?: string
          is_active?: boolean
          name: string
          note?: string | null
          phone?: string | null
          tax_code?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          email?: string | null
          id?: string
          is_active?: boolean
          name?: string
          note?: string | null
          phone?: string | null
          tax_code?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      stock_thresholds: {
        Row: {
          branch_id: string
          min_qty: number
          product_id: string
          updated_at: string
        }
        Insert: {
          branch_id: string
          min_qty: number
          product_id: string
          updated_at?: string
        }
        Update: {
          branch_id?: string
          min_qty?: number
          product_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      stock_lots: {
        Row: {
          branch_id: string
          created_at: string
          expiry_date: string | null
          id: string
          lot_no: string
          product_id: string
          qty_on_hand: number
          received_at: string
          unit_cost: number
          updated_at: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          expiry_date?: string | null
          id?: string
          lot_no?: string
          product_id: string
          qty_on_hand?: number
          received_at?: string
          unit_cost?: number
          updated_at?: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          expiry_date?: string | null
          id?: string
          lot_no?: string
          product_id?: string
          qty_on_hand?: number
          received_at?: string
          unit_cost?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_lots_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_documents: {
        Row: {
          branch_id: string
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          cancelled_by_name: string | null
          code: string
          created_at: string
          created_by: string
          created_by_name: string | null
          doc_type: string
          id: string
          note: string | null
          posted_at: string | null
          posted_by: string | null
          posted_by_name: string | null
          status: string
          supplier_id: string | null
          supplier_ref: string | null
          total_cost: number
          updated_at: string
        }
        Insert: {
          branch_id: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cancelled_by_name?: string | null
          code: string
          created_at?: string
          created_by: string
          created_by_name?: string | null
          doc_type: string
          id?: string
          note?: string | null
          posted_at?: string | null
          posted_by?: string | null
          posted_by_name?: string | null
          status?: string
          supplier_id?: string | null
          supplier_ref?: string | null
          total_cost?: number
          updated_at?: string
        }
        Update: {
          branch_id?: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cancelled_by_name?: string | null
          code?: string
          created_at?: string
          created_by?: string
          created_by_name?: string | null
          doc_type?: string
          id?: string
          note?: string | null
          posted_at?: string | null
          posted_by?: string | null
          posted_by_name?: string | null
          status?: string
          supplier_id?: string | null
          supplier_ref?: string | null
          total_cost?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_documents_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_document_lines: {
        Row: {
          counted_qty: number | null
          document_id: string
          expiry_date: string | null
          id: string
          line_no: number
          lot_id: string | null
          lot_no: string
          note: string | null
          product_id: string
          qty: number
          system_qty: number | null
          unit_cost: number
          entered_cost: number | null
          entered_qty: number | null
          unit_factor: number
          unit_id: string | null
          unit_name: string | null
        }
        Insert: {
          counted_qty?: number | null
          document_id: string
          expiry_date?: string | null
          id?: string
          line_no: number
          lot_id?: string | null
          lot_no?: string
          note?: string | null
          product_id: string
          qty?: number
          system_qty?: number | null
          unit_cost?: number
          entered_cost?: number | null
          entered_qty?: number | null
          unit_factor?: number
          unit_id?: string | null
          unit_name?: string | null
        }
        Update: {
          counted_qty?: number | null
          document_id?: string
          expiry_date?: string | null
          id?: string
          line_no?: number
          lot_id?: string | null
          lot_no?: string
          note?: string | null
          product_id?: string
          qty?: number
          system_qty?: number | null
          unit_cost?: number
          entered_cost?: number | null
          entered_qty?: number | null
          unit_factor?: number
          unit_id?: string | null
          unit_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_document_lines_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "stock_documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_document_lines_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_movements: {
        Row: {
          balance_after: number
          branch_id: string
          created_at: string
          created_by: string | null
          document_id: string | null
          document_line_id: string | null
          id: string
          invoice_id: string | null
          invoice_line_id: string | null
          lot_id: string
          product_id: string
          qty: number
          reason: string
          return_id: string | null
          unit_cost: number
        }
        Insert: {
          balance_after: number
          branch_id: string
          created_at?: string
          created_by?: string | null
          document_id?: string | null
          document_line_id?: string | null
          id?: string
          invoice_id?: string | null
          invoice_line_id?: string | null
          lot_id: string
          product_id: string
          qty: number
          reason: string
          return_id?: string | null
          unit_cost: number
        }
        Update: {
          balance_after?: number
          branch_id?: string
          created_at?: string
          created_by?: string | null
          document_id?: string | null
          document_line_id?: string | null
          id?: string
          invoice_id?: string | null
          invoice_line_id?: string | null
          lot_id?: string
          product_id?: string
          qty?: number
          reason?: string
          return_id?: string | null
          unit_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_lot_id_fkey"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "stock_documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_return_id_fkey"
            columns: ["return_id"]
            isOneToOne: false
            referencedRelation: "sales_returns"
            referencedColumns: ["id"]
          },
        ]
      }
      sales_returns: {
        Row: {
          branch_id: string
          code: string
          created_at: string
          created_by: string
          created_by_name: string | null
          id: string
          invoice_id: string
          reason: string
          refund_amount: number
          refund_method: string
          shift_id: string
        }
        Insert: {
          branch_id: string
          code: string
          created_at?: string
          created_by: string
          created_by_name?: string | null
          id?: string
          invoice_id: string
          reason: string
          refund_amount: number
          refund_method: string
          shift_id: string
        }
        Update: {
          branch_id?: string
          code?: string
          created_at?: string
          created_by?: string
          created_by_name?: string | null
          id?: string
          invoice_id?: string
          reason?: string
          refund_amount?: number
          refund_method?: string
          shift_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sales_returns_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      sales_return_lines: {
        Row: {
          amount: number
          id: string
          invoice_line_id: string
          name: string
          product_id: string
          qty: number
          return_id: string
        }
        Insert: {
          amount: number
          id?: string
          invoice_line_id: string
          name: string
          product_id: string
          qty: number
          return_id: string
        }
        Update: {
          amount?: number
          id?: string
          invoice_line_id?: string
          name?: string
          product_id?: string
          qty?: number
          return_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sales_return_lines_return_id_fkey"
            columns: ["return_id"]
            isOneToOne: false
            referencedRelation: "sales_returns"
            referencedColumns: ["id"]
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
          is_system: boolean
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          is_system?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          is_system?: boolean
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
      service_species: {
        Row: {
          service_id: string
          species_id: string
        }
        Insert: {
          service_id: string
          species_id: string
        }
        Update: {
          service_id?: string
          species_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_species_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "pet_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_species_species_id_fkey"
            columns: ["species_id"]
            isOneToOne: false
            referencedRelation: "species"
            referencedColumns: ["id"]
          },
        ]
      }
      boarding_settings: {
        Row: {
          branch_id: string
          check_in_from: string
          check_out_by: string
          day_stay_nights: number
          late_half_until: string
          max_nights: number
          updated_at: string
        }
        Insert: {
          branch_id: string
          check_in_from?: string
          check_out_by?: string
          day_stay_nights?: number
          late_half_until?: string
          max_nights?: number
          updated_at?: string
        }
        Update: {
          branch_id?: string
          check_in_from?: string
          check_out_by?: string
          day_stay_nights?: number
          late_half_until?: string
          max_nights?: number
          updated_at?: string
        }
        Relationships: []
      }
      boarding_stays: {
        Row: {
          branch_id: string
          cancel_reason: string | null
          cancelled_at: string | null
          checked_in_at: string | null
          checked_out_at: string | null
          code: string
          created_at: string
          created_by: string | null
          customer_id: string
          customer_name: string
          customer_phone: string
          emergency_phone: string | null
          id: string
          note: string | null
          planned_in_at: string
          planned_out_at: string
          source: string
          status: string
          updated_at: string
        }
        Insert: {
          branch_id: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          checked_in_at?: string | null
          checked_out_at?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          customer_id: string
          customer_name: string
          customer_phone: string
          emergency_phone?: string | null
          id?: string
          note?: string | null
          planned_in_at: string
          planned_out_at: string
          source?: string
          status?: string
          updated_at?: string
        }
        Update: {
          branch_id?: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          checked_in_at?: string | null
          checked_out_at?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          customer_id?: string
          customer_name?: string
          customer_phone?: string
          emergency_phone?: string | null
          id?: string
          note?: string | null
          planned_in_at?: string
          planned_out_at?: string
          source?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      boarding_stay_pets: {
        Row: {
          belongings: string | null
          belongings_returned: boolean
          branch_id: string
          charged_nights: number
          created_at: string
          est_night_price: number
          feeding: string | null
          id: string
          is_extra_pet: boolean
          kennel_id: string
          kennel_type_id: string
          line_no: number
          medication: string | null
          night_price: number | null
          nights: string
          pet_id: string
          pet_name: string
          stay_id: string
          status: string
          updated_at: string
          vaccine_checked: boolean
          vaccine_note: string | null
          weight_kg: number | null
        }
        Insert: {
          belongings?: string | null
          belongings_returned?: boolean
          branch_id: string
          charged_nights: number
          created_at?: string
          est_night_price: number
          feeding?: string | null
          id?: string
          is_extra_pet?: boolean
          kennel_id: string
          kennel_type_id: string
          line_no: number
          medication?: string | null
          night_price?: number | null
          nights: string
          pet_id: string
          pet_name: string
          stay_id: string
          status?: string
          updated_at?: string
          vaccine_checked?: boolean
          vaccine_note?: string | null
          weight_kg?: number | null
        }
        Update: {
          belongings?: string | null
          belongings_returned?: boolean
          branch_id?: string
          charged_nights?: number
          created_at?: string
          est_night_price?: number
          feeding?: string | null
          id?: string
          is_extra_pet?: boolean
          kennel_id?: string
          kennel_type_id?: string
          line_no?: number
          medication?: string | null
          night_price?: number | null
          nights?: string
          pet_id?: string
          pet_name?: string
          stay_id?: string
          status?: string
          updated_at?: string
          vaccine_checked?: boolean
          vaccine_note?: string | null
          weight_kg?: number | null
        }
        Relationships: []
      }
      kennel_type_prices: {
        Row: {
          branch_id: string | null
          created_at: string
          extra_pet_night_price: number | null
          id: string
          kennel_type_id: string
          night_price: number
          updated_at: string
        }
        Insert: {
          branch_id?: string | null
          created_at?: string
          extra_pet_night_price?: number | null
          id?: string
          kennel_type_id: string
          night_price: number
          updated_at?: string
        }
        Update: {
          branch_id?: string | null
          created_at?: string
          extra_pet_night_price?: number | null
          id?: string
          kennel_type_id?: string
          night_price?: number
          updated_at?: string
        }
        Relationships: []
      }
      kennel_types: {
        Row: {
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          is_public: boolean
          max_pets: number
          max_weight_kg: number | null
          name: string
          photo_url: string | null
          purpose: string
          sort_order: number
          species_ids: string[]
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_public?: boolean
          max_pets?: number
          max_weight_kg?: number | null
          name: string
          photo_url?: string | null
          purpose?: string
          sort_order?: number
          species_ids?: string[]
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_public?: boolean
          max_pets?: number
          max_weight_kg?: number | null
          name?: string
          photo_url?: string | null
          purpose?: string
          sort_order?: number
          species_ids?: string[]
          updated_at?: string
        }
        Relationships: []
      }
      kennels: {
        Row: {
          branch_id: string
          code: string
          created_at: string
          id: string
          is_active: boolean
          kennel_type_id: string
          name: string | null
          sort_order: number
          status: string
          updated_at: string
        }
        Insert: {
          branch_id: string
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          kennel_type_id: string
          name?: string | null
          sort_order?: number
          status?: string
          updated_at?: string
        }
        Update: {
          branch_id?: string
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          kennel_type_id?: string
          name?: string | null
          sort_order?: number
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      spa_resources: {
        Row: {
          branch_id: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          sort_order: number
          updated_at: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          sort_order?: number
          updated_at?: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      staff_branches: {
        Row: {
          branch_id: string
          created_at: string
          does_services: boolean
          role: string
          updated_at: string
          user_id: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          does_services?: boolean
          role: string
          updated_at?: string
          user_id: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          does_services?: boolean
          role?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_branches_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_branches_role_fkey"
            columns: ["role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["name"]
          },
          {
            foreignKeyName: "staff_branches_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      species: {
        Row: {
          created_at: string
          description: string | null
          icon: string | null
          id: string
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: string
          is_active?: boolean
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
      weight_brackets: {
        Row: {
          created_at: string
          id: string
          label: string
          max_kg: number | null
          min_kg: number
          sort_order: number
          species_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          label: string
          max_kg?: number | null
          min_kg: number
          sort_order?: number
          species_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          label?: string
          max_kg?: number | null
          min_kg?: number
          sort_order?: number
          species_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "weight_brackets_species_id_fkey"
            columns: ["species_id"]
            isOneToOne: false
            referencedRelation: "species"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      pet_overview: {
        Row: {
          allergies: string | null
          behavior_notes: string | null
          birth_date: string | null
          bracket_id: string | null
          bracket_label: string | null
          breed: string | null
          created_at: string | null
          id: string | null
          name: string | null
          neutered: boolean | null
          owner_count: number | null
          owner_id: string | null
          owner_name: string | null
          owner_phone: string | null
          photo_url: string | null
          sex: string | null
          species_icon: string | null
          species_id: string | null
          species_name: string | null
          status: string | null
          weight_kg: number | null
          weight_measured_at: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      can_inventory: { Args: { p_branch?: string; p_method: string }; Returns: boolean }
      cancel_stock_document: { Args: { p_id: string; p_reason?: string }; Returns: undefined }
      create_sales_return: { Args: { p: Json }; Returns: Json }
      post_stock_document: { Args: { p_id: string }; Returns: undefined }
      save_stock_document: { Args: { p: Json }; Returns: string }
      sellable_stock: {
        Args: { p_branch: string; p_products: string[] }
        Returns: { product_id: string; qty: number }[]
      }
      list_product_groups: {
        Args: {
          p_brand?: string
          p_category?: string
          p_include_archived?: boolean
          p_limit?: number
          p_offset?: number
          p_search?: string
        }
        Returns: Json
      }
      list_product_categories: {
        Args: {
          p_include_inactive?: boolean
          p_limit?: number
          p_offset?: number
          p_roots_only?: boolean
          p_search?: string
        }
        Returns: Json
      }
      list_product_brands: {
        Args: { p_include_inactive?: boolean; p_limit?: number; p_offset?: number; p_search?: string }
        Returns: Json
      }
      save_product_category: { Args: { p: Json }; Returns: string }
      save_product_brand: { Args: { p: Json }; Returns: string }
      move_product_category: { Args: { p_direction: string; p_id: string }; Returns: undefined }
      delete_product_category: { Args: { p_id: string }; Returns: undefined }
      delete_product_brand: { Args: { p_id: string }; Returns: undefined }
      product_group_json: { Args: { p_all: boolean; p_group: string }; Returns: Json }
      save_product_group: { Args: { p: Json }; Returns: string }
      my_customer_id: { Args: never; Returns: string }
      my_addresses: { Args: never; Returns: Json }
      save_my_address: { Args: { p: Json }; Returns: Json }
      set_default_my_address: { Args: { p_id: string }; Returns: undefined }
      delete_my_address: { Args: { p_id: string }; Returns: undefined }
      shop_cart_lines: { Args: { p_lines: Json }; Returns: Json }
      shop_product_groups: {
        Args: { p_search?: string; p_category?: string; p_brand?: string; p_sort?: string; p_limit?: number; p_offset?: number }
        Returns: Json
      }
      shop_related_groups: { Args: { p_group: string; p_limit?: number }; Returns: Json }
      my_profile: { Args: never; Returns: Json }
      save_my_profile: { Args: { p: Json }; Returns: Json }
      spa_public_catalog: { Args: { p_branch?: string | null }; Returns: Json }
      spa_web_rules: { Args: never; Returns: Json }
      spa_web_slots: { Args: { p_branch: string; p_date: string; p_minutes: number }; Returns: Json }
      spa_web_quote: { Args: { p_branch: string; p_items: Json }; Returns: Json }
      book_my_appointment: { Args: { p: Json }; Returns: Json }
      my_pets: { Args: never; Returns: Json }
      my_appointments: { Args: { p_scope?: string; p_page?: number; p_page_size?: number }; Returns: Json }
      cancel_my_appointment: { Args: { p_id: string; p_reason?: string | null }; Returns: undefined }
      can_link_accounts: { Args: never; Returns: boolean }
      search_unlinked_accounts: {
        Args: { p_text: string; p_limit?: number }
        Returns: { user_id: string; full_name: string | null; phone: string | null; email: string | null }[]
      }
      link_customer_account: { Args: { p_customer: string; p_user: string }; Returns: undefined }
      shop_public_settings: { Args: never; Returns: Json }
      shop_admin_settings: { Args: never; Returns: Json }
      save_shop_settings: { Args: { p: Json }; Returns: Json }
      place_shop_order: { Args: { p: Json }; Returns: Json }
      my_shop_orders: { Args: { p_status?: string | null; p_page?: number; p_page_size?: number }; Returns: Json }
      my_shop_order: { Args: { p_code: string }; Returns: Json }
      cancel_my_shop_order: { Args: { p_code: string; p_reason?: string | null }; Returns: Json }
      list_shop_orders: {
        Args: { p_branch?: string | null; p_status?: string | null; p_search?: string | null; p_page?: number; p_page_size?: number }
        Returns: Json
      }
      get_shop_order: { Args: { p_id: string }; Returns: Json }
      confirm_shop_order: { Args: { p_id: string; p_shipping_fee?: number | null }; Returns: Json }
      pack_shop_order: { Args: { p_id: string }; Returns: Json }
      ship_shop_order: { Args: { p_id: string; p_tracking_code: string }; Returns: Json }
      deliver_shop_order: { Args: { p_id: string }; Returns: Json }
      return_shop_order: { Args: { p_id: string; p_reason: string }; Returns: Json }
      cancel_shop_order: { Args: { p_id: string; p_reason: string }; Returns: Json }
      shop_order_badge: { Args: { p_branch?: string | null }; Returns: number }
      pay_pickup_shop_order: { Args: { p_id: string; p_payments: Json }; Returns: Json }
      set_product_group_active: { Args: { p_active: boolean; p_group: string }; Returns: undefined }
      branch_prices: {
        Args: { p_branch: string; p_products: string[] }
        Returns: { price: number; product_id: string }[]
      }
      product_unit_price: { Args: { p_branch?: string; p_product: string; p_unit?: string }; Returns: number }
      set_product_branch_prices: { Args: { p_prices: Json; p_product: string }; Returns: undefined }
      find_by_barcode: { Args: { p_branch?: string; p_code: string }; Returns: Json }
      import_products: { Args: { p_dry_run?: boolean; p_file_name?: string; p_rows: Json }; Returns: Json }
      export_products: { Args: { p_limit?: number; p_offset?: number }; Returns: Json }
      import_pets: { Args: { p_dry_run?: boolean; p_rows: Json }; Returns: Json }
      import_suppliers: { Args: { p_dry_run?: boolean; p_rows: Json }; Returns: Json }
      find_products_by_sku: {
        Args: { p_skus: string[] }
        Returns: { sku: string; product_id: string; name: string; unit: string; track_stock: boolean; units: Json }[]
      }
      set_min_stock: {
        Args: { p_branch: string; p_min: number | null; p_product: string }
        Returns: undefined
      }
      stock_alert_counts: { Args: { p_branch: string; p_expiry_days?: number }; Returns: Json }
      stock_summary: {
        Args: {
          p_branch: string
          p_expiry_days?: number
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_status?: string
        }
        Returns: {
          barcode: string | null
          expired: number
          expiring: number
          is_active: boolean
          min_qty: number | null
          name: string
          next_expiry: string | null
          on_hand: number
          product_id: string
          sellable: number
          sku: string | null
          stock_value: number
          total_count: number
          unit: string
        }[]
      }
      can_pos: { Args: { p_branch: string; p_method: string }; Returns: boolean }
      can_report: { Args: { p_branch?: string; p_method: string }; Returns: boolean }
      report_overview: { Args: { p_branch: string | null; p_from: string; p_to: string }; Returns: Json }
      report_top_items: {
        Args: {
          p_branch: string | null
          p_from: string
          p_kind?: string
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_sort?: string
          p_to: string
        }
        Returns: {
          cost: number | null
          gross_profit: number | null
          invoice_count: number
          item_id: string
          item_type: string
          name: string
          net_revenue: number
          qty_returned: number
          qty_sold: number
          refunds: number
          share: number
          sku: string | null
          total_count: number
          unit: string | null
        }[]
      }
      report_staff_revenue: {
        Args: {
          p_branch: string | null
          p_from: string
          p_limit?: number
          p_offset?: number
          p_role?: string
          p_search?: string
          p_to: string
        }
        Returns: {
          avg_ticket: number | null
          cancelled_count: number | null
          invoice_count: number | null
          name: string | null
          net_sales: number
          pet_count: number | null
          refunds: number | null
          share: number | null
          staff_id: string | null
          ticket_count: number | null
          total_count: number
        }[]
      }
      report_adjustments: {
        Args: {
          p_branch: string | null
          p_from: string
          p_kind?: string
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_to: string
        }
        Returns: {
          amount: number
          at: string
          branch_id: string
          by_name: string | null
          code: string
          id: string
          invoice_code: string
          invoice_id: string
          item_summary: string | null
          kind: string
          method: string | null
          reason: string | null
          total_count: number
        }[]
      }
      report_shifts: {
        Args: {
          p_branch: string | null
          p_from: string
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_status?: string
          p_to: string
        }
        Returns: {
          branch_code: string
          card_in: number
          cash_in: number
          closed_at: string | null
          closed_by_name: string | null
          code: string
          counted_cash: number | null
          difference: number | null
          expected_cash: number | null
          id: string
          invoice_count: number
          opened_at: string
          opened_by_name: string | null
          opening_cash: number
          refund_cash: number
          sales_total: number
          status: string
          total_count: number
          transfer_in: number
        }[]
      }
      report_revenue_series: {
        Args: { p_branch: string | null; p_bucket?: string; p_from: string; p_to: string }
        Returns: {
          bucket: string
          card: number
          cash: number
          discount: number
          gross: number
          invoice_count: number
          net_revenue: number
          net_sales: number
          refunds: number
          shop: number
          spa: number
          transfer: number
        }[]
      }
      can_boarding: { Args: { p_branch?: string; p_method: string }; Returns: boolean }
      boarding_availability: {
        Args: { p_branch: string; p_from: string; p_to: string }
        Returns: Json
      }
      boarding_board: { Args: { p_branch: string; p_date?: string }; Returns: Json }
      boarding_quote: { Args: { p: Json; p_branch: string; p_stay?: string }; Returns: Json }
      cancel_boarding_stay: { Args: { p_id: string; p_reason?: string }; Returns: undefined }
      get_boarding_stay: { Args: { p_id: string }; Returns: Json }
      list_boarding_stays: {
        Args: {
          p_branch: string
          p_from?: string
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_status?: string
          p_to?: string
        }
        Returns: Json
      }
      mark_boarding_no_show: { Args: { p_id: string }; Returns: undefined }
      add_care_log: { Args: { p: Json; p_stay_pet: string }; Returns: string }
      delete_care_log: { Args: { p_id: string }; Returns: undefined }
      add_boarding_extra: { Args: { p_qty?: number; p_service: string; p_stay_pet: string }; Returns: string }
      remove_boarding_extra: { Args: { p_id: string }; Returns: undefined }
      check_in_boarding: { Args: { p_emergency_phone?: string; p_id: string; p_pets: Json }; Returns: Json }
      extend_boarding_stay: { Args: { p_id: string; p_planned_out_at: string }; Returns: undefined }
      boarding_checkout_preview: { Args: { p_at?: string; p_id: string }; Returns: Json }
      check_out_boarding: { Args: { p_id: string; p_returned?: string[] }; Returns: Json }
      save_boarding_stay: { Args: { p: Json; p_id?: string }; Returns: Json }
      boarding_settings_get: { Args: { p_branch: string }; Returns: Json }
      list_kennel_types: {
        Args: {
          p_active_only?: boolean
          p_branch: string
          p_page?: number
          p_page_size?: number
          p_search?: string
        }
        Returns: Json
      }
      list_kennels: {
        Args: { p_branch: string; p_page?: number; p_page_size?: number; p_search?: string; p_type?: string }
        Returns: Json
      }
      save_boarding_settings: { Args: { p: Json; p_branch: string }; Returns: undefined }
      save_kennel: { Args: { p: Json; p_id?: string }; Returns: string }
      save_kennel_type: { Args: { p: Json; p_id?: string }; Returns: string }
      set_kennel_status: { Args: { p_id: string; p_status: string }; Returns: undefined }
      can_schedule: { Args: { p_branch: string; p_method: string }; Returns: boolean }
      billable_boarding_charges: { Args: { p_branch: string; p_customer: string }; Returns: Json }
      billable_appointment_items: { Args: { p_branch: string; p_customer: string }; Returns: Json }
      cancel_appointment: { Args: { p_id: string; p_reason?: string }; Returns: undefined }
      check_in_appointment: { Args: { p_id: string; p_weights?: Json }; Returns: undefined }
      get_appointment: { Args: { p_id: string }; Returns: Json }
      mark_no_show: { Args: { p_id: string }; Returns: undefined }
      set_appointment_item_status: { Args: { p_item: string; p_status: string }; Returns: undefined }
      list_appointments: {
        Args: {
          p_branch: string
          p_from?: string
          p_page?: number
          p_page_size?: number
          p_search?: string
          p_status?: string
          p_to?: string
        }
        Returns: Json
      }
      list_branch_staff: {
        Args: { p_branch: string }
        Returns: { does_services: boolean; name: string; role: string; user_id: string }[]
      }
      save_appointment: { Args: { p: Json; p_id?: string }; Returns: Json }
      save_branch_hours: { Args: { p: Json; p_branch: string }; Returns: undefined }
      save_spa_resource: { Args: { p: Json; p_id?: string }; Returns: string }
      set_staff_does_services: {
        Args: { p_branch: string; p_user: string; p_value: boolean }
        Returns: undefined
      }
      spa_day_board: { Args: { p_branch: string; p_date: string }; Returns: Json }
      spa_week_hours: { Args: { p_branch: string }; Returns: Json }
      cancel_invoice: { Args: { p_id: string; p_reason: string }; Returns: undefined }
      cash_shift_summary: { Args: { p_shift: string }; Returns: Json }
      close_cash_shift: {
        Args: { p_counted_cash: number; p_note?: string; p_shift: string }
        Returns: Json
      }
      create_invoice: { Args: { p: Json }; Returns: Json }
      create_order: { Args: { p: Json }; Returns: string }
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      has_permission: {
        Args: { p_branch?: string; p_method: string; p_permission: string }
        Returns: boolean
      }
      my_permissions: {
        Args: { p_branch?: string }
        Returns: {
          branch_id: string
          methods: string[]
          permission: string
          role: string
        }[]
      }
      get_service_price: {
        Args: {
          p_branch_id?: string
          p_service_id: string
          p_species_id: string
          p_weight_kg: number
        }
        Returns: number
      }
      is_admin: { Args: never; Returns: boolean }
      is_display_name_available: {
        Args: { p_display_name: string }
        Returns: boolean
      }
      is_staff: { Args: never; Returns: boolean }
      is_super_admin: { Args: never; Returns: boolean }
      open_cash_shift: {
        Args: { p_branch: string; p_note?: string; p_opening_cash: number }
        Returns: string
      }
      register_pet: { Args: { p: Json }; Returns: string }
      save_pet_combo: { Args: { p: Json; p_id?: string }; Returns: string }
      save_pet_service: { Args: { p: Json; p_id?: string }; Returns: string }
      save_role: { Args: { p: Json; p_id?: string }; Returns: string }
      save_staff_branches: { Args: { p: Json; p_user: string }; Returns: undefined }
      save_service_prices: {
        Args: {
          p_branch_id?: string
          p_rows: Json
          p_service_id: string
          p_species_id: string
        }
        Returns: undefined
      }
      save_species: { Args: { p: Json; p_id?: string }; Returns: string }
      save_weight_brackets: {
        Args: { p_rows: Json; p_species_id: string }
        Returns: undefined
      }
      search_customers: {
        Args: { p_limit?: number; p_text: string }
        Returns: {
          customer_id: string | null
          email: string | null
          full_name: string
          note: string | null
          pet_count: number
          phone: string
          user_id: string | null
        }[]
      }
      seed_default_weight_brackets: {
        Args: { p_species_id: string }
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
